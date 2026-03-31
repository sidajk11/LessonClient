// ExampleSentenceCreateViewModel.swift

import Foundation

@MainActor
final class ExampleSentenceCreateViewModel: ObservableObject {
    
    let wordId: Int
    @Published var text: String = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    init(wordId: Int) { self.wordId = wordId }

    func create() async throws -> [ExampleSentence] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "invalid.form", code: 0, userInfo: [NSLocalizedDescriptionKey: "문장을 입력해 주세요."])
        }
        
        text = text.replacingOccurrences(of: "’", with: "'")
        
        isSaving = true
        defer { isSaving = false }

        var exampleSentences: [ExampleSentence] = []
        let paras = text.components(separatedBy: "\n\n")
        for para in paras {
            var components = para.components(separatedBy: .newlines)
            let sentence = components.removeFirst().trimmed
            let translations = [ExampleSentenceTranslation].parse(from: components)

            // Example와 ExampleSentence를 분리해서 생성합니다.
            let example = try await ExampleDataSource.shared.createExample(
                vocabularyId: wordId
            )
            let exampleSentence = try await ExampleSentenceDataSource.shared.createExampleSentence(
                payload: ExampleSentenceCreate(
                    exampleId: example.id,
                    text: sentence,
                    translations: translations
                )
            )
            exampleSentences.append(exampleSentence)
        }
        
        let word = try await VocabularyDataSource.shared.vocabulary(id: wordId)
        
        for exampleSentence in exampleSentences {
            do {
                // 생성 직후에는 token이 없을 수 있어서 매니저가 필요한 토큰을 보강합니다.
                _ = try await GenerateExerciseUseCase.shared.autoGenerateMissingExercises(
                    exampleSentence: exampleSentence,
                    targetVocabulary: word
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        
        
        return exampleSentences
    }
}
