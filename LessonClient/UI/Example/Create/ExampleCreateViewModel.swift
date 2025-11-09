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
            let text = components.removeFirst().trimmed
            let translations = [ExampleTranslation].parse(from: components)

            let example = try await ExampleDataSource.shared.createExample(
                text: text,
                wordId: wordId,
                translations: translations
            )
            examples.append(example)
        }
        
        let word = try await WordDataSource.shared.word(id: wordId)
        
        for example in examples {
            await autoGenerateCombine(example: example, word: word)
            await autoGenerateSelect(example: example, word: word)
        }
        
        
        return examples
    }
    
    private func autoGenerateCombine(example: Example, word: Word) async {
        do {
            let exercises = try await ExerciseDataSource.shared.list(exampleId: example.id)
            if !exercises.contains(where: { $0.type == .combine }) {
                let allWordsInSentence = example.text.tokenize(word: word.text).filter { !punctuationSet.contains($0) }
                let content = example.text.underlinesText
                await submit(example: example, content: content, type: .combine, wordOptionTextList: allWordsInSentence)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func autoGenerateSelect(example: Example, word: Word) async {
        guard let lessonId = word.lessonId else { return }
        do {
            let exercises = try await ExerciseDataSource.shared.list(exampleId: example.id)
            let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
            if !exercises.contains(where: { $0.type == .select }) {
                let allWordsInSentence = example.text.tokenize(word: word.text).filter { !punctuationSet.contains($0) }
                
                var selectedTestWords: [String] = []
                if allWordsInSentence.contains(where: { $0.lowercased() == word.text.lowercased() }) {
                    selectedTestWords.append(word.text)
                } else if allWordsInSentence.contains(where: { $0.lowercased() == word.text.lowercased() + "s" }) {
                    selectedTestWords.append(word.text + "s")
                } else if allWordsInSentence.contains(where: { $0.lowercased() == word.text.lowercased() + "es" }) {
                    selectedTestWords.append(word.text + "es")
                } else if allWordsInSentence.contains(where: { $0.lowercased() == word.text.lowercased() + "ed" }) {
                    selectedTestWords.append(word.text + "ed")
                }
                
                let wordsLearned = try await WordDataSource.shared.wordsLessThan(unit: lesson.unit).map { $0.text }
                let dummyWords = wordsLearned
                    .filter { dummyWord in
                        !dummyWord.contains(" ")
                    }
                    .filter { dummyWord in
                        !allWordsInSentence.contains(where: {
                            $0.lowercased() == dummyWord.lowercased()
                        })
                    }
                let index = Int.random(in: 0 ..< dummyWords.count)
                selectedTestWords.append(dummyWords[index])
                
                var tokens = example.text.tokenize(word: word.text)
                tokens = tokens.map { word in
                    if selectedTestWords.contains(where: { $0.lowercased() == word.lowercased() }) {
                        "_"
                    } else {
                        word
                    }
                }
                
                if !tokens.contains("_") || selectedTestWords.count <= 1 {
                    errorMessage = "Generate select exercise failed!"
                    return
                }
                
                let content = tokens.joinTokens()
                
                await submit(example: example, content: content, type: .select, wordOptionTextList: selectedTestWords)
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func submit(example: Example, content: String, type: ExerciseType, wordOptionTextList: [String]) async {
        var transList: [ExerciseTranslation] = []
        let trans = ExerciseTranslation(langCode: .enUS, content: content, question: nil)
        transList.append(trans)
        
        var wordsOptions: [ExerciseWordOption] = []
        wordsOptions = wordOptionTextList.map {
            let text = NL.lowercaseAvailable(sentence: example.text, word: $0) ? $0.lowercased() : $0
            let translation = ExerciseOptionTranslation(langCode: .enUS, text: text)
            return ExerciseWordOption(translations: [translation])
        }
        
        let exerciseCrate = ExerciseUpdate(
            exampleId: example.id,
            type: type,
            wordOptions: wordsOptions,
            options: nil,
            translations: transList
        )
        do {
            let _ = try await ExerciseDataSource.shared.create(exercise: exerciseCrate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
