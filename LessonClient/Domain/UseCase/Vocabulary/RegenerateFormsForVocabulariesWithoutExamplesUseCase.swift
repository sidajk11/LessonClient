import Foundation

@MainActor
final class RegenerateFormsForVocabulariesWithoutExamplesUseCase {
    struct Result {
        let totalVocabularyCount: Int
        let resolvedWordCount: Int
        let regeneratedWordCount: Int
        let createdFormCount: Int
        let skippedWordCount: Int
        let failures: [String]
    }

    private struct RegenerationTask {
        let word: WordRead
        let lemma: String
    }

    enum RegenerationError: LocalizedError {
        case noLinkedWord(vocabularyText: String)
        case emptyLemma(wordId: Int)

        var errorDescription: String? {
            switch self {
            case .noLinkedWord(let vocabularyText):
                return "연결된 word를 찾지 못했습니다: \(vocabularyText)"
            case .emptyLemma(let wordId):
                return "word lemma가 비어 있습니다. wordId=\(wordId)"
            }
        }
    }

    static let shared = RegenerateFormsForVocabulariesWithoutExamplesUseCase()

    private let wordDataSource = WordDataSource.shared
    private let formDataSource = WordFormDataSource.shared
    private let autoGenerateWordSensesUseCase = AutoGenerateWordSensesUseCase.shared
    private let wordUseCase = WordUseCase.shared

    private init() {}

    func run(
        cutoffDate: Date,
        onProgress: (String) -> Void = { _ in }
    ) async -> Result {
        do {
            let words = try await fetchAllWords(onProgress: onProgress)
            return await regenerate(
                words: words,
                cutoffDate: cutoffDate,
                initialFailures: [],
                onProgress: onProgress
            )
        } catch {
            return Result(
                totalVocabularyCount: 0,
                resolvedWordCount: 0,
                regeneratedWordCount: 0,
                createdFormCount: 0,
                skippedWordCount: 0,
                failures: [error.localizedDescription]
            )
        }
    }

    func run(
        vocabularyInput: String,
        cutoffDate: Date,
        onProgress: (String) -> Void = { _ in }
    ) async -> Result {
        let inputs = vocabularyInput
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map(\.trimmed)
            .filter { !$0.isEmpty }

        guard !inputs.isEmpty else {
            return Result(
                totalVocabularyCount: 0,
                resolvedWordCount: 0,
                regeneratedWordCount: 0,
                createdFormCount: 0,
                skippedWordCount: 0,
                failures: ["vocabulary를 입력해주세요."]
            )
        }

        var seenVocabularyIds: Set<Int> = []
        var vocabularies: [Vocabulary] = []
        var failures: [String] = []

        for (index, input) in inputs.enumerated() {
            let input = input.normalizedApostrophe
            onProgress("입력 vocabulary 조회 중... (\(index + 1)/\(inputs.count)) \(input)")

            do {
                let found = try await wordUseCase.findVocabulary(byEnglish: input)
                let matched = found.filter { $0.text.trimmed.caseInsensitiveCompare(input) == .orderedSame }

                guard !matched.isEmpty else {
                    failures.append("\(input): vocabulary를 찾지 못했습니다.")
                    continue
                }

                for vocabulary in matched where seenVocabularyIds.insert(vocabulary.id).inserted {
                    vocabularies.append(vocabulary)
                }
            } catch {
                failures.append("\(input): \(error.localizedDescription)")
            }
        }

        return await regenerate(
            vocabularies: vocabularies,
            cutoffDate: cutoffDate,
            initialFailures: failures,
            onProgress: onProgress
        )
    }

    func countWords(
        createdAfter cutoffDate: Date,
        onProgress: (String) -> Void = { _ in }
    ) async throws -> Int {
        let words = try await fetchAllWords(onProgress: onProgress)
        return words.reduce(into: 0) { count, word in
            guard let createdAt = word.createdAt, createdAt > cutoffDate else { return }
            count += 1
        }
    }
}

private extension RegenerateFormsForVocabulariesWithoutExamplesUseCase {
    func regenerate(
        words: [WordRead],
        cutoffDate: Date,
        initialFailures: [String],
        onProgress: (String) -> Void
    ) async -> Result {
        var failures = initialFailures

        guard !words.isEmpty else {
            return Result(
                totalVocabularyCount: 0,
                resolvedWordCount: 0,
                regeneratedWordCount: 0,
                createdFormCount: 0,
                skippedWordCount: 0,
                failures: failures
            )
        }

        let tasks = prepareTasks(from: words, cutoffDate: cutoffDate, failures: &failures)

        var regeneratedWordCount = 0
        var createdFormCount = 0
        var skippedWordCount = 0

        for (index, task) in tasks.enumerated() {
            onProgress("form 재생성 중... (\(index + 1)/\(tasks.count)) \(task.lemma)")

            do {
                let created = try await autoGenerateWordSensesUseCase.regenerateForms(for: task.word)

                if created == 0 {
                    skippedWordCount += 1
                } else {
                    regeneratedWordCount += 1
                    createdFormCount += created
                }
            } catch {
                failures.append("\(task.lemma): \(error.localizedDescription)")
            }
        }

        return Result(
            totalVocabularyCount: words.count,
            resolvedWordCount: tasks.count,
            regeneratedWordCount: regeneratedWordCount,
            createdFormCount: createdFormCount,
            skippedWordCount: skippedWordCount,
            failures: failures
        )
    }

    func regenerate(
        vocabularies: [Vocabulary],
        cutoffDate: Date,
        initialFailures: [String],
        onProgress: (String) -> Void
    ) async -> Result {
        var failures = initialFailures

        guard !vocabularies.isEmpty else {
            return Result(
                totalVocabularyCount: 0,
                resolvedWordCount: 0,
                regeneratedWordCount: 0,
                createdFormCount: 0,
                skippedWordCount: 0,
                failures: failures
            )
        }

        let tasks = await prepareTasks(
            from: vocabularies,
            cutoffDate: cutoffDate,
            failures: &failures,
            onProgress: onProgress
        )

        var regeneratedWordCount = 0
        var createdFormCount = 0
        var skippedWordCount = 0

        for (index, task) in tasks.enumerated() {
            onProgress("form 재생성 중... (\(index + 1)/\(tasks.count)) \(task.lemma)")

            do {
                let created = try await autoGenerateWordSensesUseCase.regenerateForms(for: task.word)

                if created == 0 {
                    skippedWordCount += 1
                } else {
                    regeneratedWordCount += 1
                    createdFormCount += created
                }
            } catch {
                failures.append("\(task.lemma): \(error.localizedDescription)")
            }
        }

        return Result(
            totalVocabularyCount: vocabularies.count,
            resolvedWordCount: tasks.count,
            regeneratedWordCount: regeneratedWordCount,
            createdFormCount: createdFormCount,
            skippedWordCount: skippedWordCount,
            failures: failures
        )
    }

    func fetchAllWords(
        onProgress: (String) -> Void
    ) async throws -> [WordRead] {
        let pageSize = 200
        var offset = 0
        var output: [WordRead] = []

        while true {
            onProgress("전체 word 조회 중... \(offset)")
            let page = try await wordDataSource.listWords(limit: pageSize, offset: offset)
            output.append(contentsOf: page)

            guard page.count == pageSize else { break }
            offset += page.count
        }

        return output
    }

    private func prepareTasks(
        from words: [WordRead],
        cutoffDate: Date,
        failures: inout [String]
    ) -> [RegenerationTask] {
        words.compactMap { word in
            let isEligibleByDate = word.createdAt.map { $0 < cutoffDate } ?? false
            guard isEligibleByDate else { return nil }

            let lemma = word.lemma.trimmed
            guard !lemma.isEmpty else {
                failures.append("wordId=\(word.id): \(RegenerationError.emptyLemma(wordId: word.id).localizedDescription)")
                return nil
            }

            return RegenerationTask(word: word, lemma: lemma)
        }
    }

    private func prepareTasks(
        from vocabularies: [Vocabulary],
        cutoffDate: Date,
        failures: inout [String],
        onProgress: (String) -> Void
    ) async -> [RegenerationTask] {
        var tasks: [RegenerationTask] = []
        var seenWordIds: Set<Int> = []

        for (index, vocabulary) in vocabularies.enumerated() {
            onProgress("연결 word 조회 중... (\(index + 1)/\(vocabularies.count)) \(vocabulary.text)")

            do {
                let word = try await resolveLinkedWord(for: vocabulary)
                let isEligibleByDate = word.createdAt.map { $0 < cutoffDate } ?? false
                guard isEligibleByDate else { continue }

                let lemma = word.lemma.trimmed
                guard !lemma.isEmpty else {
                    throw RegenerationError.emptyLemma(wordId: word.id)
                }
                guard seenWordIds.insert(word.id).inserted else { continue }
                tasks.append(.init(word: word, lemma: lemma))
            } catch {
                failures.append("\(vocabulary.text): \(error.localizedDescription)")
            }
        }

        return tasks
    }

    func resolveLinkedWord(for vocabulary: Vocabulary) async throws -> WordRead {
        if let wordId = vocabulary.wordId {
            return try await wordDataSource.word(id: wordId)
        }

        if let senseId = vocabulary.senseId {
            let sense = try await wordDataSource.wordSense(senseId: senseId)
            return try await wordDataSource.word(id: sense.wordId)
        }

        if let formId = vocabulary.formId {
            let form = try await formDataSource.wordForm(id: formId)
            return try await wordDataSource.word(id: form.wordId)
        }

        throw RegenerationError.noLinkedWord(vocabularyText: vocabulary.text)
    }
}
