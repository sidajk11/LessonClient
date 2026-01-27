// ExampleCreateViewModel.swift

import Foundation

@MainActor
final class ExampleCreateViewModel: ObservableObject {
    
    let wordId: Int
    @Published var text: String = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    init(wordId: Int) { self.wordId = wordId }

    func create() async throws -> [Example] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "invalid.form", code: 0, userInfo: [NSLocalizedDescriptionKey: "문장을 입력해 주세요."])
        }
        
        text = text.replacingOccurrences(of: "’", with: "'")
        
        isSaving = true
        defer { isSaving = false }

        var examples: [Example] = []
        let paras = text.components(separatedBy: "\n\n")
        for para in paras {
            var components = para.components(separatedBy: .newlines)
            let sentence = components.removeFirst().trimmed
            let translations = [ExampleTranslation].parse(from: components)

            let example = try await ExampleDataSource.shared.createExample(
                sentence: sentence,
                wordId: wordId,
                translations: translations
            )
            examples.append(example)
        }
        
        let word = try await VocabularyDataSource.shared.word(id: wordId)
        
        for example in examples {
            await autoGenerateCombine(example: example, word: word)
            await autoGenerateSelect(example: example, word: word)
        }
        
        
        return examples
    }
    
    private func autoGenerateCombine(example: Example, word: Vocabulary) async {
        do {
            let practices = try await PracticeDataSource.shared.list(exampleId: example.id)
            if !practices.contains(where: { $0.type == .combine }) {
                let allVocabularysInSentence = example.sentence.tokenize(word: word.text).filter { !punctuationSet.contains($0) }
                let content = example.sentence.underlinesText
                await submit(example: example, content: content, type: .combine, wordOptionTextList: allVocabularysInSentence)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func autoGenerateSelect(example: Example, word: Vocabulary) async {
        guard let lessonId = word.lessonId else { return }
        do {
            let practices = try await PracticeDataSource.shared.list(exampleId: example.id)
            let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
            if !practices.contains(where: { $0.type == .select }) {
                let allVocabularysInSentence = example.sentence.tokenize(word: word.text).filter { !punctuationSet.contains($0) }
                
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
                
                var tokens = example.sentence.tokenize(word: word.text)
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
                
                await submit(example: example, content: content, type: .select, wordOptionTextList: selectedTestVocabularys)
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func submit(example: Example, content: String, type: ExerciseType, wordOptionTextList: [String]) async {
        var transList: [ExerciseTranslation] = []
        let trans = ExerciseTranslation(langCode: .enUS, content: content, question: nil)
        transList.append(trans)
        
        var wordsOptions: [ExerciseVocabularyOption] = []
        wordsOptions = wordOptionTextList.map {
            let text = NL.lowercaseAvailable(sentence: example.sentence, word: $0) ? $0.lowercased() : $0
            let translation = PracticeOptionTranslation(langCode: .enUS, text: text)
            return ExerciseVocabularyOption(translations: [translation])
        }
        
        let practiceCrate = ExerciseUpdate(
            exampleId: example.id,
            type: type,
            wordOptions: wordsOptions,
            options: nil,
            translations: transList
        )
        do {
            let _ = try await PracticeDataSource.shared.create(practice: practiceCrate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
