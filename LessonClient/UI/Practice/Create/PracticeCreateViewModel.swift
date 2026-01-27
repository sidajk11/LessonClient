// MARK: - Practice Create ViewModel

import SwiftUI
import Combine

@MainActor
final class PracticeCreateViewModel: ObservableObject {
    // Inputs
    let example: Example
    var lesson: Lesson?
    var word: Vocabulary?
    
    @Published var type: ExerciseType = .select // change as needed
    @Published var selectedIndexes: [Int] = []
    // 영어문장에서 추출한 단어들
    @Published var allVocabularysInSentence: [String] = []
    // 번역에서 추출한 단어들
    @Published var allTransVocabularys: [LangCode: [PracticeOptionTranslation]] = [:]
    
    @Published private var dummyVocabularys: [String] = []
    @Published private var selectedDummyVocabularys: [String] = []
    
    @Published var wordOptionTextList: [String] = []
    @Published var correctionOptionId: Int = 0
    @Published var options: [ExerciseOptionUpdate] = []      // 보기

    // UI State
    @Published var translation: String = ""
    @Published var sentence: String = ""
    @Published var content: String = ""
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var createdPractice: Exercise?
    
    var selectedTestVocabularys: [String] {
        return selectedIndexes.map { self.allVocabularysInSentence[$0] }
    }

    var canSubmit: Bool {
        !isSubmitting
    }
    
    private var cancellables = Set<AnyCancellable>()

    init(example: Example, lesson: Lesson?, word: Vocabulary?) {
        self.example = example
        self.lesson = lesson
        self.word = word
        if lesson == nil {
            Task {
                do {
                    let word = try await VocabularyDataSource.shared.word(id: example.wordId)
                    if let lessonId = word.lessonId {
                        self.lesson = try await LessonDataSource.shared.lesson(id: lessonId)
                        if let lesson = self.lesson {
                            self.dummyVocabularys = try await VocabularyDataSource.shared.wordsLessThan(unit: lesson.unit).map { $0.text }
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        translation = example.translations.koText()
        allVocabularysInSentence = words(from: example.sentence).filter { !punctuationSet.contains($0) }
        allTransVocabularys = transVocabularys(from: example.translations)
        
        bind()
    }
}

extension PracticeCreateViewModel {
    func selectableDummyVocabularys() -> [String] {
        return dummyVocabularys
    }
    func selectDummyVocabulary(word: String) {
        if selectedDummyVocabularys.contains(word) {
            selectedDummyVocabularys.removeAll(where: { $0 == word })
        } else {
            selectedDummyVocabularys.append(word)
        }
    }
    
    func isDummyVocabularySelected(word: String) -> Bool {
        selectedDummyVocabularys.contains(word)
    }
}

extension PracticeCreateViewModel {
    func selectTestVocabulary(index: Int) {
        
        if selectedIndexes.contains(index) {
            selectedIndexes.removeAll(where: { $0 == index })
        } else {
            selectedIndexes.append(index)
        }
    }
    
    func isTestVocabularySelected(index: Int) -> Bool {
        selectedIndexes.contains(index)
    }
}

extension PracticeCreateViewModel {
    func autoGenerate() async {
        do {
            let practices = try await PracticeDataSource.shared.list(exampleId: example.id)
            if !practices.contains(where: { $0.type == .combine }) {
                type = .combine
                await submit()
            }
            
            if !practices.contains(where: { $0.type == .select }), let word {
                type = .select
                
                selectedIndexes = []
                if let index = allVocabularysInSentence.firstIndex(where: { $0.lowercased() == word.text.lowercased() }) {
                    selectedIndexes.append(index)
                } else if let index = allVocabularysInSentence.firstIndex(where: { $0.lowercased() == word.text.lowercased() + "s" }) {
                    selectedIndexes.append(index)
                } else if let index = allVocabularysInSentence.firstIndex(where: { $0.lowercased() == word.text.lowercased() + "es" }) {
                    selectedIndexes.append(index)
                } else if let index = allVocabularysInSentence.firstIndex(where: { $0.lowercased() == word.text.lowercased() + "ed" }) {
                    selectedIndexes.append(index)
                }
                let dummyVocabularys = dummyVocabularys
                    .filter { dummyVocabulary in
                        !dummyVocabulary.contains(" ")
                    }
                    .filter { dummyVocabulary in
                        !allVocabularysInSentence.contains(where: {
                            $0.lowercased() == dummyVocabulary.lowercased()
                        })
                    }
                let index = Int.random(in: 0 ..< dummyVocabularys.count)
                selectedDummyVocabularys = [dummyVocabularys[index]]
                
                if !content.contains("_") || selectedIndexes.count == 0 {
                    errorMessage = "Generate select practice failed!"
                    return
                }
                await submit()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func submit() async {
        errorMessage = nil
        createdPractice = nil
        isSubmitting = true
        defer { isSubmitting = false }
        
        var transList: [ExerciseTranslation] = []
        if type == .combine || type == .select {
            let trans = ExerciseTranslation(langCode: .enUS, content: content, question: nil)
            transList.append(trans)
        }
        var wordsOptions: [ExerciseVocabularyOption] = []
        if type == .combine || type == .select, wordOptionTextList.count > 0 {
            wordsOptions = wordOptionTextList.map {
                let text = NL.lowercaseAvailable(sentence: example.sentence, word: $0) ? $0.lowercased() : $0
                let translation = PracticeOptionTranslation(langCode: .enUS, text: text)
                return ExerciseVocabularyOption(translations: [translation])
            }
        }
        
        let practiceCrate = ExerciseUpdate(
            exampleId: example.id,
            type: type,
            wordOptions: wordsOptions,
            options: options,
            translations: transList
        )
        do {
            let practice = try await PracticeDataSource.shared.create(practice: practiceCrate)
            createdPractice = practice
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
extension PracticeCreateViewModel {
    private func bind() {
        $type
            .removeDuplicates()
            .filter { $0 == .combine }
            .sink { [weak self] _ in
                guard let self else { return }
                sentence = example.translations.text(langCode: .ko)
                content = content(from: example.sentence)
                wordOptionTextList = allVocabularysInSentence
            }
            .store(in: &cancellables)
        
        $type
            .removeDuplicates()
            .filter { $0 == .select }
            .combineLatest($selectedIndexes)
            .sink { [weak self] (type, selectedIndexes) in
                guard let self else { return }
                sentence = example.sentence
                var tokens = sentence.tokenize(word: word?.text)
                for index in selectedIndexes {
                    tokens[index] = "_"
                }
                
                content = tokens.joinTokens()
                    
            }
            .store(in: &cancellables)
        
        $type
            .filter { $0 == .select }
            .combineLatest($selectedIndexes) { $1 }
            .compactMap { $0 }
            .combineLatest($selectedDummyVocabularys)
            .map { selectedIndexes, selectedDummyVocabularys in
                var words = selectedDummyVocabularys
                let selectedTestVocabularys = selectedIndexes.map { self.allVocabularysInSentence[$0] }
                words.insert(contentsOf: selectedTestVocabularys, at: 0)
                return words
            }
            .assign(to: &$wordOptionTextList)
    }
    
    private func content(from sentence: String) -> String {
        return sentence.underlinesText
    }

    private func words(from sentence: String) -> [String] {
        // 문장에 포함된 단어들 (중복 제거, 순서 유지)
        return sentence.tokenize(word: word?.text)
    }
    
    private func transVocabularys(from translations: [ExampleTranslation]) -> [LangCode: [PracticeOptionTranslation]] {
        /*
         This is my phone.
         ko:이것은 내 휴대폰이야.
         es:Este es mi teléfono.
         */
        var dict: [LangCode: [PracticeOptionTranslation]] = [:]
        translations.forEach { trans in
            let words = NL.words(text: trans.text)
            let optionTranslations = words.map {
                PracticeOptionTranslation(langCode: trans.langCode, text: $0)
            }
            dict[trans.langCode] = optionTranslations
        }
        return dict
    }
}


