import Foundation

struct ExampleTokenVocabularyStatusBatch {
    let hasUnresolvableVocabularyByExampleId: [Int: Bool]
    let unresolvableVocabularyWordByExampleId: [Int: String]
    let hasMissingTokenVocabularyByExampleId: [Int: Bool]
    let missingTokenVocabularyWordByExampleId: [Int: String]
    let highestUnitByExampleId: [Int: Int]
    let highestUnitWordByExampleId: [Int: String]
}

actor ExampleTokenVocabularyStatusLoader {
    private let vocabularyAnalysisUseCase = SentenceVocabularyAnalysisUseCase.shared

    func load(for examples: [Example]) async -> ExampleTokenVocabularyStatusBatch {
        var unresolvedById: [Int: Bool] = [:]
        var unresolvedWordById: [Int: String] = [:]
        var missingTokenVocabularyById: [Int: Bool] = [:]
        var missingTokenVocabularyWordById: [Int: String] = [:]
        var highestUnitById: [Int: Int] = [:]
        var highestUnitWordById: [Int: String] = [:]

        await withTaskGroup(of: (Int, Bool?, String?, Bool?, String?, Int?, String?).self) { group in
            for example in examples {
                group.addTask { [vocabularyAnalysisUseCase] in
                    let missingTokenVocabularyWord = example.allTokens.first { token in
                        let surface = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                        return !surface.isEmpty &&
                            !punctuationSet.contains(surface) &&
                            token.vocabulary == nil
                    }?.surface
                    let unresolvedWord = try? await vocabularyAnalysisUseCase
                        .firstUnresolvableVocabulary(tokens: example.allTokens)
                    let highestToken = example.allTokens
                        .compactMap { token -> (Int, String)? in
                            guard let vocabulary = token.vocabulary,
                                  let unit = vocabulary.unit else {
                                return nil
                            }
                            return (unit, vocabulary.text)
                        }
                        .max { lhs, rhs in lhs.0 < rhs.0 }

                    return (
                        example.id,
                        unresolvedWord != nil,
                        unresolvedWord,
                        missingTokenVocabularyWord != nil,
                        missingTokenVocabularyWord,
                        highestToken?.0,
                        highestToken?.1
                    )
                }
            }

            for await (
                exampleId,
                hasUnresolvable,
                unresolvedWord,
                hasMissingTokenVocabulary,
                missingTokenVocabularyWord,
                highestUnit,
                highestUnitWord
            ) in group {
                if let hasUnresolvable {
                    unresolvedById[exampleId] = hasUnresolvable
                }
                if let unresolvedWord, !unresolvedWord.isEmpty {
                    unresolvedWordById[exampleId] = unresolvedWord
                }
                if let hasMissingTokenVocabulary {
                    missingTokenVocabularyById[exampleId] = hasMissingTokenVocabulary
                }
                if let missingTokenVocabularyWord, !missingTokenVocabularyWord.isEmpty {
                    missingTokenVocabularyWordById[exampleId] = missingTokenVocabularyWord
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
            hasMissingTokenVocabularyByExampleId: missingTokenVocabularyById,
            missingTokenVocabularyWordByExampleId: missingTokenVocabularyWordById,
            highestUnitByExampleId: highestUnitById,
            highestUnitWordByExampleId: highestUnitWordById
        )
    }
}
