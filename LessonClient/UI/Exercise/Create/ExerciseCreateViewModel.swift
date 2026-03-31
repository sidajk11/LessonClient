// MARK: - Practice Create ViewModel

import SwiftUI
import Combine

@MainActor
final class ExerciseCreateViewModel: ObservableObject {
    // Inputs
    let exampleSentence: ExampleSentence
    let exampleId: Int
    let vocabularyId: Int?
    var lesson: Lesson?
    var vocab: Vocabulary?
    
    @Published var type: ExerciseType = .select // change as needed
    @Published var selectedIndexes: [Int] = []
    // 영어문장에서 추출한 단어들
    @Published var allVocabularysInSentence: [String] = []
    
    @Published private var dummyVocabularys: [String] = []
    @Published private var selectedDummyVocabularys: [String] = []
    
    @Published var wordOptionTextList: [String] = []
    @Published var correctionOptionId: Int = 0

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

    init(exampleSentence: ExampleSentence, exampleId: Int, vocabularyId: Int?, lesson: Lesson?, word: Vocabulary?) {
        self.exampleSentence = exampleSentence
        self.exampleId = exampleId
        self.vocabularyId = vocabularyId
        self.lesson = lesson
        self.vocab = word
        if lesson == nil {
            Task {
                do {
                    if let vocabularyId {
                        let word = try await VocabularyDataSource.shared.vocabulary(id: vocabularyId)
                        self.vocab = self.vocab ?? word
                        if let lessonId = word.lessonId {
                            self.lesson = try await LessonDataSource.shared.lesson(id: lessonId)
                            if let lesson = self.lesson {
                                self.dummyVocabularys = try await VocabularyDataSource.shared.wordsLessThan(unit: lesson.unit).map { $0.text }
                            }
                        }
                    }
                    
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        translation = exampleSentence.translations.koText()
        allVocabularysInSentence = words(from: exampleSentence.text).filter { !punctuationSet.contains($0) }
        
        bind()
    }
}

extension ExerciseCreateViewModel {
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

extension ExerciseCreateViewModel {
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

extension ExerciseCreateViewModel {
    func autoGenerate() async {
        errorMessage = nil
        createdPractice = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let targetVocabulary = try await resolvedTargetVocabulary()
            let created = try await GenerateExerciseUseCase.shared.autoGenerateMissingExercises(
                exampleSentence: exampleSentence,
                targetVocabulary: targetVocabulary
            )
            createdPractice = created.last
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func submit() async {
        errorMessage = nil
        createdPractice = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // submit 생성도 use case를 통해 일관되게 처리합니다.
            let draft = GenerateExerciseUseCase.Draft(
                type: type,
                prompt: content,
                optionTexts: wordOptionTextList
            )
            let practice = try await GenerateExerciseUseCase.shared.createExercise(
                exampleSentence: exampleSentence,
                draft: draft
            )
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
extension ExerciseCreateViewModel {
    private func bind() {
        $type
            .removeDuplicates()
            .filter { $0 == .combine }
            .sink { [weak self] _ in
                guard let self else { return }
                sentence = exampleSentence.translations.text(langCode: .ko)
                content = content(from: exampleSentence.text)
                wordOptionTextList = allVocabularysInSentence
            }
            .store(in: &cancellables)
        
        $type
            .removeDuplicates()
            .filter { $0 == .select }
            .combineLatest($selectedIndexes)
            .sink { [weak self] (type, selectedIndexes) in
                guard let self else { return }
                sentence = exampleSentence.text
                var tokens = sentence.tokenize(word: vocab?.text)
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
        return sentence.tokenize(word: vocab?.text)
    }

    private func resolvedTargetVocabulary() async throws -> Vocabulary? {
        if let vocab {
            return vocab
        }
        guard let vocabularyId else {
            return nil
        }

        // autoGenerate 시점에 vocabulary가 아직 로드되지 않았을 수 있어 한 번 더 보강합니다.
        let loadedVocabulary = try await VocabularyDataSource.shared.vocabulary(id: vocabularyId)
        vocab = loadedVocabulary
        return loadedVocabulary
    }
}
