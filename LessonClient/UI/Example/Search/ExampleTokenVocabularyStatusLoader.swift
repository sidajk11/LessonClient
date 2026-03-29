import Foundation

struct ExampleTokenVocabularyStatusBatch {
    let hasUnresolvableVocabularyByExampleId: [Int: Bool]
    let unresolvableVocabularyWordByExampleId: [Int: String]
    let highestUnitByExampleId: [Int: Int]
    let highestUnitWordByExampleId: [Int: String]
}

actor ExampleTokenVocabularyStatusLoader {
    func load(for examples: [Example]) async -> ExampleTokenVocabularyStatusBatch {
        var unresolvedById: [Int: Bool] = [:]
        var unresolvedWordById: [Int: String] = [:]
        var highestUnitById: [Int: Int] = [:]
        var highestUnitWordById: [Int: String] = [:]

        await withTaskGroup(of: (Int, Bool?, String?, Int?, String?).self) { group in
            for example in examples {
                group.addTask {
                    // token에 vocabulary가 없으면 미학습 단어로 간주합니다.
                    let unresolvedWord = example.allTokens.first { token in
                        let surface = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                        return !surface.isEmpty &&
                            !punctuationSet.contains(surface) &&
                            token.vocabulary == nil
                    }?.surface

                    if let unresolvedWord, !unresolvedWord.isEmpty {
                        return (example.id, true, unresolvedWord, nil, nil)
                    }

                    // sentence token 응답에 포함된 vocabulary.unit 기준으로 최고 unit을 계산합니다.
                    let highestToken = example.allTokens
                        .compactMap { token -> (Int, String)? in
                            guard let vocabulary = token.vocabulary,
                                  let unit = vocabulary.unit else {
                                return nil
                            }
                            return (unit, vocabulary.text)
                        }
                        .max { lhs, rhs in lhs.0 < rhs.0 }

                    return (example.id, false, nil, highestToken?.0, highestToken?.1)
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
