import Foundation

@MainActor
final class RegenerateWordsBeforeDateUseCase {
    private struct RegenerationTask {
        let existingWord: WordRead?
        let lemma: String
    }

    struct Result {
        let totalWordCount: Int
        let eligibleWordCount: Int
        let regeneratedWordCount: Int
        let failures: [String]
        let wasStopped: Bool
        let stoppedByFailure: Bool
    }

    static let shared = RegenerateWordsBeforeDateUseCase()

    private let wordDataSource = WordDataSource.shared
    private let formDataSource = WordFormDataSource.shared
    private let pronunciationDataSource = PronunciationDataSource.shared
    private let autoGenerateWordSensesUseCase = AutoGenerateWordSensesUseCase.shared
    private let wordUseCase = WordUseCase.shared

    private init() {}

    func run(
        cutoffDate: Date,
        onProgress: (String) -> Void = { _ in },
        shouldContinue: () -> Bool = { true }
    ) async -> Result {
        do {
            let fetchResult = try await fetchAllWords(
                onProgress: onProgress,
                shouldContinue: shouldContinue
            )
            let words = fetchResult.words
            let eligibleWords = words.filter { word in
                word.createdAt.map { $0 < cutoffDate } ?? false
            }

            guard !eligibleWords.isEmpty else {
                return Result(
                    totalWordCount: words.count,
                    eligibleWordCount: 0,
                    regeneratedWordCount: 0,
                    failures: [],
                    wasStopped: fetchResult.wasStopped,
                    stoppedByFailure: false
                )
            }

            var regeneratedWordCount = 0
            var failures: [String] = []

            for (index, word) in eligibleWords.enumerated() {
                guard shouldContinue() else {
                    return Result(
                        totalWordCount: words.count,
                        eligibleWordCount: eligibleWords.count,
                        regeneratedWordCount: regeneratedWordCount,
                        failures: failures,
                        wasStopped: true,
                        stoppedByFailure: false
                    )
                }

                let lemma = word.lemma.trimmed
                guard !isArabicNumberOnly(lemma) else { continue }
                onProgress("word 재생성 중... (\(index + 1)/\(eligibleWords.count)) \(lemma)")

                guard !lemma.isEmpty else {
                    failures.append("wordId=\(word.id): word lemma가 비어 있습니다.")
                    continue
                }

                do {
                    try await deleteLinkedWord(word)
                    let generation = try await autoGenerateWordSensesUseCase.autoGenerateSenses(
                        from: lemma,
                        onProgress: { message in
                            onProgress("word 재생성 중... (\(index + 1)/\(eligibleWords.count)) \(lemma) - \(message)")
                        }
                    )

                    if let failureMessage = generation.generation.failures.first {
                        failures.append("\(lemma): \(failureMessage)")
                        continue
                    }

                    regeneratedWordCount += 1
                } catch {
                    failures.append("\(lemma): \(error.localizedDescription)")
                    continue
                }
            }

            return Result(
                totalWordCount: words.count,
                eligibleWordCount: eligibleWords.count,
                regeneratedWordCount: regeneratedWordCount,
                failures: failures,
                wasStopped: fetchResult.wasStopped,
                stoppedByFailure: false
            )
        } catch {
            return Result(
                totalWordCount: 0,
                eligibleWordCount: 0,
                regeneratedWordCount: 0,
                failures: [error.localizedDescription],
                wasStopped: false,
                stoppedByFailure: false
            )
        }
    }

    func run(
        wordInput: String,
        cutoffDate: Date,
        deleteExistingWord: Bool,
        onProgress: (String) -> Void = { _ in },
        shouldContinue: () -> Bool = { true }
    ) async -> Result {
        let inputs = wordInput
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map(\.trimmed)
            .filter { !$0.isEmpty }

        guard !inputs.isEmpty else {
            return Result(
                totalWordCount: 0,
                eligibleWordCount: 0,
                regeneratedWordCount: 0,
                failures: ["word를 입력해주세요."],
                wasStopped: false,
                stoppedByFailure: false
            )
        }

        var failures: [String] = []
        var tasks: [RegenerationTask] = []
        var seen: Set<String> = []

        for (index, input) in inputs.enumerated() {
            guard shouldContinue() else {
                return Result(
                    totalWordCount: inputs.count,
                    eligibleWordCount: tasks.count,
                    regeneratedWordCount: 0,
                    failures: failures,
                    wasStopped: true,
                    stoppedByFailure: false
                )
            }

            let lemma = input.normalizedApostrophe
            let key = lemma.lowercased()
            guard seen.insert(key).inserted else { continue }
            guard !isArabicNumberOnly(lemma) else { continue }

            onProgress("입력 word 조회 중... (\(index + 1)/\(inputs.count)) \(lemma)")

            do {
                if let existing = try await wordUseCase.findWord(byEnglish: lemma) {
                    tasks.append(.init(existingWord: existing, lemma: lemma))
                } else {
                    tasks.append(.init(existingWord: nil, lemma: lemma))
                }
            } catch {
                failures.append("\(lemma): \(error.localizedDescription)")
                continue
            }
        }

        let result = await regenerate(
            tasks: tasks,
            totalWordCount: inputs.count,
            failures: failures,
            deleteExistingWord: deleteExistingWord,
            onProgress: onProgress,
            shouldContinue: shouldContinue
        )
        return result
    }
}

private extension RegenerateWordsBeforeDateUseCase {
    struct FetchWordsResult {
        let words: [WordRead]
        let wasStopped: Bool
    }

    func fetchAllWords(
        onProgress: (String) -> Void,
        shouldContinue: () -> Bool
    ) async throws -> FetchWordsResult {
        let pageSize = 200
        var offset = 0
        var output: [WordRead] = []

        while true {
            guard shouldContinue() else {
                return FetchWordsResult(words: output, wasStopped: true)
            }

            onProgress("전체 word 조회 중... \(offset)")
            let page = try await wordDataSource.listWords(limit: pageSize, offset: offset)
            output.append(contentsOf: page)

            guard page.count == pageSize else {
                return FetchWordsResult(words: output, wasStopped: false)
            }
            offset += page.count
        }
    }

    func deleteLinkedWord(_ word: WordRead) async throws {
        let pronunciations = try await pronunciationDataSource.listPronunciations(wordId: word.id, limit: 200, offset: 0)
        for pronunciation in pronunciations {
            try await pronunciationDataSource.deletePronunciation(id: pronunciation.id)
        }

        let forms = try await formDataSource.listWordForms(wordId: word.id, limit: 200, offset: 0)
        for form in forms {
            try await formDataSource.deleteWordForm(id: form.id)
        }

        let senses = try await wordDataSource.listWordSenses(wordId: word.id, limit: 200, offset: 0)
        for sense in senses {
            try await wordDataSource.deleteWordSense(senseId: sense.id)
        }

        try await wordDataSource.deleteWord(id: word.id)
    }

    private func regenerate(
        tasks: [RegenerationTask],
        totalWordCount: Int,
        failures: [String],
        deleteExistingWord: Bool,
        onProgress: (String) -> Void,
        shouldContinue: () -> Bool
    ) async -> Result {
        guard !tasks.isEmpty else {
            return Result(
                totalWordCount: totalWordCount,
                eligibleWordCount: 0,
                regeneratedWordCount: 0,
                failures: failures,
                wasStopped: false,
                stoppedByFailure: false
            )
        }

        var regeneratedWordCount = 0
        var collectedFailures = failures

        for (index, task) in tasks.enumerated() {
            guard shouldContinue() else {
                return Result(
                    totalWordCount: totalWordCount,
                    eligibleWordCount: tasks.count,
                    regeneratedWordCount: regeneratedWordCount,
                    failures: collectedFailures,
                    wasStopped: true,
                    stoppedByFailure: false
                )
            }

            let lemma = task.lemma.trimmed
            guard !isArabicNumberOnly(lemma) else { continue }
            onProgress("word 재생성 중... (\(index + 1)/\(tasks.count)) \(lemma)")

            guard !lemma.isEmpty else {
                collectedFailures.append("빈 lemma는 처리할 수 없습니다.")
                continue
            }

            do {
                if deleteExistingWord, let existingWord = task.existingWord {
                    try await deleteLinkedWord(existingWord)
                }

                let generation = try await autoGenerateWordSensesUseCase.autoGenerateSenses(
                    from: lemma,
                    onProgress: { message in
                        onProgress("word 재생성 중... (\(index + 1)/\(tasks.count)) \(lemma) - \(message)")
                    }
                )

                if let failureMessage = generation.generation.failures.first {
                    collectedFailures.append("\(lemma): \(failureMessage)")
                    continue
                }

                regeneratedWordCount += 1
            } catch {
                collectedFailures.append("\(lemma): \(error.localizedDescription)")
                continue
            }
        }

        return Result(
            totalWordCount: totalWordCount,
            eligibleWordCount: tasks.count,
            regeneratedWordCount: regeneratedWordCount,
            failures: collectedFailures,
            wasStopped: false,
            stoppedByFailure: false
        )
    }

    func isArabicNumberOnly(_ value: String) -> Bool {
        let trimmed = value.trimmed
        guard !trimmed.isEmpty else { return false }

        return trimmed.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }
}
