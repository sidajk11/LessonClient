import Foundation

struct ExampleTokenVocabularyStatusBatch {
    let hasUnresolvableVocabularyByExampleId: [Int: Bool]
    let unresolvableVocabularyWordByExampleId: [Int: String]
    let highestUnitByExampleId: [Int: Int]
    let highestUnitWordByExampleId: [Int: String]
}

actor ExampleTokenVocabularyStatusLoader {
    private let sentenceUseCase = SentenceUseCase.shared

    func load(for examples: [Example]) async -> ExampleTokenVocabularyStatusBatch {
        var unresolvedById: [Int: Bool] = [:]
        var unresolvedWordById: [Int: String] = [:]
        var highestUnitById: [Int: Int] = [:]
        var highestUnitWordById: [Int: String] = [:]

        await withTaskGroup(of: (Int, Bool?, String?, Int?, String?).self) { group in
            for example in examples {
                group.addTask { [sentenceUseCase] in
                    let unresolvedWord = try? await sentenceUseCase.firstUnresolvableVocabulary(tokens: example.tokens)
                    // 미학습 단어
                    if let unresolvedWord, !unresolvedWord.isEmpty {
                        return (example.id, true, unresolvedWord, nil, nil)
                    }
                    
                    // 너무 높은 unit
                    let highestInfo = try? await sentenceUseCase.highestUnitInfo(tokens: example.tokens)
                    return (example.id, false, nil, highestInfo?.unit, highestInfo?.vocabularyText)
                }
            }

            for await (exampleId, hasUnresolvable, unresolvedWord, highestUnit, highestUnitWord) in group {
                if let hasUnresolvable {
                    unresolvedById[exampleId] = hasUnresolvable
                }
                if let unresolvedWord, !unresolvedWord.isEmpty {
                    unresolvedWordById[exampleId] = unresolvedWord
                }
                if let highestUnit {
                    highestUnitById[exampleId] = highestUnit
                }
                if let highestUnitWord, !highestUnitWord.isEmpty {
                    highestUnitWordById[exampleId] = highestUnitWord
                }
            }
        }

        return ExampleTokenVocabularyStatusBatch(
            hasUnresolvableVocabularyByExampleId: unresolvedById,
            unresolvableVocabularyWordByExampleId: unresolvedWordById,
            highestUnitByExampleId: highestUnitById,
            highestUnitWordByExampleId: highestUnitWordById
        )
    }
}
