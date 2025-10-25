// MARK: - Exercise Create ViewModel

import SwiftUI
import Combine
import NaturalLanguage

@MainActor
final class ExerciseCreateViewModel: ObservableObject {
    // Inputs
    let example: Example
    var lesson: Lesson?
    var word: Word?
    
    @Published var type: ExerciseType = .select // change as needed
    @Published var selectedWord: String? = nil
    // 영어문장에서 추출한 단어들
    @Published var allWords: [String] = []
    // 번역에서 추출한 단어들
    @Published var allTransWords: [LangCode: [ExerciseOptionTranslation]] = [:]
    
    @Published var wordsLearned: [Word] = []
    @Published var dummyWords: [String] = []
    
    @Published var words: [String] = []
    @Published var correctionOptionId: Int = 0
    @Published var options: [ExerciseOptionUpdate] = []      // 보기

    // UI State
    @Published var translation: String = ""
    @Published var content: String = ""
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var createdExercise: Exercise?

    var canSubmit: Bool {
        !isSubmitting
    }
    
    private var cancellables = Set<AnyCancellable>()

    init(example: Example, lesson: Lesson?, word: Word?) {
        self.example = example
        self.lesson = lesson
        self.word = word
        if lesson == nil {
            Task {
                do {
                    let word = try await WordDataSource.shared.word(id: example.wordId)
                    if let lessonId = word.lessonId {
                        self.lesson = try await LessonDataSource.shared.lesson(id: lessonId)
                        if let lesson = self.lesson {
                            let unit = Int.random(in: 1...lesson.unit)
                            self.wordsLearned = try await WordDataSource.shared.searchWords(unit: unit)
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        translation = example.translations.koText()
        allWords = words(from: example.translations.first(where: { $0.langCode == .ko })?.text ?? "")
        allTransWords = transWords(from: example.translations)
        
        bind()
    }

    func submit() async {
        errorMessage = nil
        createdExercise = nil
        isSubmitting = true
        defer { isSubmitting = false }
        
        var transList: [ExerciseTranslation] = []
        if type == .combine || type == .select {
            let trans = ExerciseTranslation(langCode: .enUS, content: content, question: nil)
            transList.append(trans)
        }
        var wordsOptions: [ExerciseWordOption] = []
        if type == .combine, words.count > 0 {
            wordsOptions = words.map {
                let translation = ExerciseOptionTranslation(langCode: .enGB, text: $0)
                return ExerciseWordOption(translations: [translation])
            }
        }
        
        let exerciseCrate = ExerciseUpdate(
            exampleId: example.id,
            type: type.rawValue,
            wordOptions: wordsOptions,
            options: options,
            translations: transList
        )
        do {
            let exercise = try await ExerciseDataSource.shared.create(exercise: exerciseCrate)
            createdExercise = exercise
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
/*
 우리 엄마랑 우리 아빠.
 _ _ _ _ _
 My, mom, and, my, dad
 */
extension ExerciseCreateViewModel {
    private func bind() {
        $type
            .removeDuplicates()
            .filter { $0 == .combine }
            .sink { [weak self] _ in
                guard let self else { return }
                content = content(from: example.translations.koText())
                words = allWords
            }
            .store(in: &cancellables)
        
        $type
            .removeDuplicates()
            .filter { $0 == .select }
            .combineLatest($selectedWord.compactMap { $0 })
            .sink { [weak self] (type, selectedWord) in
                guard let self else { return }
                let sentence = example.text
                content = sentence.replacingOccurrences(of: selectedWord, with: "_")
            }
            .store(in: &cancellables)
        
        $type
            .filter { $0 == .select }
            .combineLatest($selectedWord) { $1 }
            .compactMap { $0 }
            .combineLatest($dummyWords)
            .map { selectedWord, dummyWords in
                var words = dummyWords
                words.insert(selectedWord, at: 0)
                return words
            }
            .assign(to: &$words)
    }
    
    private func tokens(from sentence: String) -> [String] {
        // 공백 기준 분리 후 양쪽 구두점 제거
        sentence
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
            .map {
                if $0 == "a.m" {
                    return "a.m."
                } else if $0 == "p.m" {
                    return "p.m."
                } else if !$0.isName {
                    return $0.lowercased()
                } else {
                    return $0
                }
            }
    }
    
    private func content(from sentence: String) -> String {
        // 단어 수만큼 "_" 생성, 마지막 문장부호는 그대로 붙여줌
        let ws = tokens(from: sentence)
        guard !ws.isEmpty else { return "" }
        var q = Array(repeating: "_", count: ws.count).joined(separator: " ")
        if let last = sentence.last, CharacterSet.punctuationCharacters.contains(last.unicodeScalars.first!) {
            q += String(last)
        }
        return q
    }

    private func words(from sentence: String) -> [String] {
        // 문장에 포함된 단어들 (중복 제거, 순서 유지)
        var seen = Set<String>()
        return tokens(from: sentence).filter { word in
            seen.insert(word.lowercased())
            return true
        }
    }
    
    private func transWords(from translations: [ExampleTranslation]) -> [LangCode: [ExerciseOptionTranslation]] {
        /*
         This is my phone.
         ko:이것은 내 휴대폰이야.
         es:Este es mi teléfono.
         */
        var dict: [LangCode: [ExerciseOptionTranslation]] = [:]
        translations.forEach { trans in
            let words = NLTokenizer.words(text: trans.text)
            let optionTranslations = words.map {
                ExerciseOptionTranslation(langCode: trans.langCode, text: $0)
            }
            dict[trans.langCode] = optionTranslations
        }
        return dict
    }
}


