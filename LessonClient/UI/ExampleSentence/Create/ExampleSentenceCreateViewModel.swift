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

            let example = try await ExampleDataSource.shared.createExample(
                sentence: sentence,
                vocabularyId: wordId,
                translations: translations
            )
            guard let exampleSentence = example.exampleSentences.first(where: { $0.text == sentence }) ?? example.orderedExampleSentences.first else {
                throw NSError(domain: "ExampleSentenceCreateViewModel", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "생성된 ExampleSentence를 찾을 수 없습니다."
                ])
            }
            exampleSentences.append(exampleSentence)
        }
        
        let word = try await VocabularyDataSource.shared.vocabulary(id: wordId)
        
        for exampleSentence in exampleSentences {
            await autoGenerateCombine(exampleSentence: exampleSentence, word: word)
            await autoGenerateSelect(exampleSentence: exampleSentence, word: word)
        }
        
        
        return exampleSentences
    }
    
    private func autoGenerateCombine(exampleSentence: ExampleSentence, word: Vocabulary) async {
        do {
            let practices = try await ExerciseDataSource.shared.list(exampleId: exampleSentence.exampleId)
            if !practices.contains(where: { $0.type == .combine }) {
                let allVocabularysInSentence = exampleSentence.text.tokenize(word: word.text).filter { !punctuationSet.contains($0) }
                let content = exampleSentence.text.underlinesText
                await submit(exampleSentence: exampleSentence, prompt: content, type: .combine, wordOptionTextList: allVocabularysInSentence)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func autoGenerateSelect(exampleSentence: ExampleSentence, word: Vocabulary) async {
        guard let lessonId = word.lessonId else { return }
        do {
            let practices = try await ExerciseDataSource.shared.list(exampleId: exampleSentence.exampleId)
            let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
            if !practices.contains(where: { $0.type == .select }) {
                let allVocabularysInSentence = exampleSentence.text.tokenize(word: word.text).filter { !punctuationSet.contains($0) }
                
                var selectedTestVocabularys: [String] = []
                if allVocabularysInSentence.contains(where: { $0.lowercased() == word.text.lowercased() }) {
                    selectedTestVocabularys.append(word.text)
                } else if allVocabularysInSentence.contains(where: { $0.lowercased() == word.text.lowercased() + "s" }) {
                    selectedTestVocabularys.append(word.text + "s")
                } else if allVocabularysInSentence.contains(where: { $0.lowercased() == word.text.lowercased() + "es" }) {
                    selectedTestVocabularys.append(word.text + "es")
                } else if allVocabularysInSentence.contains(where: { $0.lowercased() == word.text.lowercased() + "ed" }) {
                    selectedTestVocabularys.append(word.text + "ed")
                }
                
                let wordsLearned = try await VocabularyDataSource.shared.wordsLessThan(unit: lesson.unit).map { $0.text }
                let dummyVocabularys = wordsLearned
                    .filter { dummyVocabulary in
                        !dummyVocabulary.contains(" ")
                    }
                    .filter { dummyVocabulary in
                        !allVocabularysInSentence.contains(where: {
                            $0.lowercased() == dummyVocabulary.lowercased()
                        })
                    }
                let index = Int.random(in: 0 ..< dummyVocabularys.count)
                selectedTestVocabularys.append(dummyVocabularys[index])
                
                var tokens = exampleSentence.text.tokenize(word: word.text)
                tokens = tokens.map { word in
                    if selectedTestVocabularys.contains(where: { $0.lowercased() == word.lowercased() }) {
                        "_"
                    } else {
                        word
                    }
                }
                
                if !tokens.contains("_") || selectedTestVocabularys.count <= 1 {
                    errorMessage = "Generate select practice failed!"
                    return
                }
                
                let content = tokens.joinTokens()
                
                await submit(exampleSentence: exampleSentence, prompt: content, type: .select, wordOptionTextList: selectedTestVocabularys)
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func submit(exampleSentence: ExampleSentence, prompt: String, type: ExerciseType, wordOptionTextList: [String]) async {
        var transList: [ExerciseTranslation] = []
        let trans = ExerciseTranslation(langCode: .enUS, question: nil)
        transList.append(trans)
        
        var wordsOptions: [ExerciseOptionUpdate] = []
        wordsOptions = wordOptionTextList.map {
            let text = NL.lowercaseAvailable(sentence: exampleSentence.text, word: $0) ? $0.lowercased() : $0
            return ExerciseOptionUpdate.textOption(text)
        }
        
        let practiceCrate = ExerciseCreate(
            exampleId: exampleSentence.exampleId,
            targetSentenceIds: [exampleSentence.id],
            type: type,
            prompt: prompt,
            options: wordsOptions,
            translations: transList
        )
        do {
            let _ = try await ExerciseDataSource.shared.create(practice: practiceCrate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
