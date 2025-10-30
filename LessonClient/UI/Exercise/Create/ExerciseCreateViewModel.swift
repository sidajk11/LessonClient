// MARK: - Exercise Create ViewModel

import SwiftUI
import Combine

@MainActor
final class ExerciseCreateViewModel: ObservableObject {
    // Inputs
    let example: Example
    var lesson: Lesson?
    var word: Word?
    
    @Published var type: ExerciseType = .select // change as needed
    @Published var selectedWords: [String] = []
    // 영어문장에서 추출한 단어들
    @Published var allWords: [String] = []
    // 번역에서 추출한 단어들
    @Published var allTransWords: [LangCode: [ExerciseOptionTranslation]] = [:]
    
    @Published var wordsLearned: [Word] = []
    @Published var selectableWords: [String] = []
    @Published var dummyWords: [String] = []
    
    @Published var words: [String] = []
    @Published var correctionOptionId: Int = 0
    @Published var options: [ExerciseOptionUpdate] = []      // 보기

    // UI State
    @Published var translation: String = ""
    @Published var sentence: String = ""
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
                            self.wordsLearned = try await WordDataSource.shared.wordsLessThan(unit: lesson.unit)
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        translation = example.translations.koText()
        allWords = words(from: example.text).filter { !punctuationSet.contains($0) }
        allTransWords = transWords(from: example.translations)
        
        bind()
    }
}

extension ExerciseCreateViewModel {
    func autoGenerate() async {
        do {
            let exercises = try await ExerciseDataSource.shared.list(exampleId: example.id)
            if exercises.contains(where: { $0.type == .combine }) {
                return
            }
            type = .combine
            await submit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    func selectDummyWord(word: String) {
        if dummyWords.contains(word) {
            dummyWords.removeAll(where: { $0 == word })
        } else {
            dummyWords.append(word)
        }
    }
    
    func isDummyWordSelected(word: String) -> Bool {
        dummyWords.contains(word)
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
        if type == .combine || type == .select, words.count > 0 {
            wordsOptions = words.map {
                let text = NL.lowercaseAvailable(sentence: example.text, word: $0) ? $0.lowercased() : $0
                let translation = ExerciseOptionTranslation(langCode: .enUS, text: text)
                return ExerciseWordOption(translations: [translation])
            }
        }
        
        let exerciseCrate = ExerciseUpdate(
            exampleId: example.id,
            type: type,
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
                sentence = example.translations.text(langCode: .ko)
                content = content(from: example.text)
                words = allWords
            }
            .store(in: &cancellables)
        
        $type
            .removeDuplicates()
            .filter { $0 == .select }
            .combineLatest($selectedWords.compactMap { $0 })
            .sink { [weak self] (type, selectedWords) in
                guard let self else { return }
                sentence = example.text
                var tokens = sentence.tokenize(word: word?.text)
                tokens = tokens.map { word in
                    if selectedWords.contains(where: { $0.lowercased() == word.lowercased() }) {
                        "_"
                    } else {
                        word
                    }
                }
                
                content = tokens.joinTokens()
                    
            }
            .store(in: &cancellables)
        
        $type
            .filter { $0 == .select }
            .combineLatest($selectedWords) { $1 }
            .compactMap { $0 }
            .combineLatest($dummyWords)
            .map { [weak self] selectedWords, dummyWords in
                guard let self else { return [] }
                var words = dummyWords
                let selected = selectedWords.map { word in
                    if NL.lowercaseAvailable(sentence: self.sentence, word: word) {
                        return word.lowercased()
                    } else {
                        return word
                    }
                }
                words.insert(contentsOf: selectedWords, at: 0)
                return words
            }
            .assign(to: &$words)
        
        $wordsLearned
            .map { $0.map { $0.text } }
            .combineLatest($selectedWords) { words, selectedWords in
                words.filter { word in
                    !selectedWords.contains(where: { $0.lowercased() == word.lowercased() })
                }
            }
            .assign(to: &$selectableWords)
    }
    
    private func content(from sentence: String) -> String {
        // 단어 수만큼 "_" 생성, 마지막 문장부호는 그대로 붙여줌
        let tokens = sentence.tokenize()
        
        var content: String = ""
        for token in tokens {
            if punctuationSet.contains(token) {
                content.append(token)
            } else {
                if !content.isEmpty {
                    content.append(" ")
                }
                content.append("_")
            }
        }
        
        return content
    }

    private func words(from sentence: String) -> [String] {
        // 문장에 포함된 단어들 (중복 제거, 순서 유지)
        return sentence.tokenize(word: word?.text)
    }
    
    private func transWords(from translations: [ExampleTranslation]) -> [LangCode: [ExerciseOptionTranslation]] {
        /*
         This is my phone.
         ko:이것은 내 휴대폰이야.
         es:Este es mi teléfono.
         */
        var dict: [LangCode: [ExerciseOptionTranslation]] = [:]
        translations.forEach { trans in
            let words = NL.words(text: trans.text)
            let optionTranslations = words.map {
                ExerciseOptionTranslation(langCode: trans.langCode, text: $0)
            }
            dict[trans.langCode] = optionTranslations
        }
        return dict
    }
}


