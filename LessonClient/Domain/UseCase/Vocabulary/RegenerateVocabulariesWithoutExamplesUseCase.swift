import Foundation

@MainActor
final class RegenerateVocabulariesWithoutExamplesUseCase {
    struct Result {
        let totalVocabularyCount: Int
        let resolvedWordCount: Int
        let regeneratedWordCount: Int
        let updatedVocabularyCount: Int
        let auditMismatchCount: Int
        let auditFailureCount: Int
        let applyFailureCount: Int
        let failures: [String]
    }

    private struct RegenerationTask {
        let wordId: Int?
        let lemma: String
    }

    enum RegenerationError: LocalizedError {
        case noLinkedWord(vocabularyText: String)
        case emptyLemma(wordId: Int)
        case autoGenerateFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .noLinkedWord(let vocabularyText):
                return "연결된 word를 찾지 못했습니다: \(vocabularyText)"
            case .emptyLemma(let wordId):
                return "word lemma가 비어 있습니다. wordId=\(wordId)"
            case .autoGenerateFailed(let message):
                return message
            }
        }
    }

    static let shared = RegenerateVocabulariesWithoutExamplesUseCase()

    private let vocabularyDataSource = VocabularyDataSource.shared
    private let wordDataSource = WordDataSource.shared
    private let formDataSource = WordFormDataSource.shared
    private let pronunciationDataSource = PronunciationDataSource.shared
    private let autoGenerateWordSensesUseCase = AutoGenerateWordSensesUseCase.shared
    private let vocabularyLinkAuditUseCase = VocabularyLinkAuditUseCase.shared
    private let wordUseCase = WordUseCase.shared

    private init() {}

    func run(
        cutoffDate: Date,
        onProgress: (String) -> Void = { _ in }
    ) async -> Result {
        do {
            let vocabularies = try await fetchAllVocabulariesWithoutExamples(onProgress: onProgress)
            return await regenerate(
                vocabularies: vocabularies,
                cutoffDate: cutoffDate,
                onProgress: onProgress
            )
        } catch {
            return Result(
                totalVocabularyCount: 0,
                resolvedWordCount: 0,
                regeneratedWordCount: 0,
                updatedVocabularyCount: 0,
                auditMismatchCount: 0,
                auditFailureCount: 0,
                applyFailureCount: 0,
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
                updatedVocabularyCount: 0,
                auditMismatchCount: 0,
                auditFailureCount: 0,
                applyFailureCount: 0,
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

        let result = await regenerate(
            vocabularies: vocabularies,
            cutoffDate: cutoffDate,
            onProgress: onProgress
        )
        return Result(
            totalVocabularyCount: result.totalVocabularyCount,
            resolvedWordCount: result.resolvedWordCount,
            regeneratedWordCount: result.regeneratedWordCount,
            updatedVocabularyCount: result.updatedVocabularyCount,
            auditMismatchCount: result.auditMismatchCount,
            auditFailureCount: result.auditFailureCount,
            applyFailureCount: result.applyFailureCount,
            failures: failures + result.failures
        )
    }
}

private extension RegenerateVocabulariesWithoutExamplesUseCase {
    func regenerate(
        vocabularies: [Vocabulary],
        cutoffDate: Date,
        onProgress: (String) -> Void
    ) async -> Result {
        var failures: [String] = []

        guard !vocabularies.isEmpty else {
            return Result(
                totalVocabularyCount: 0,
                resolvedWordCount: 0,
                regeneratedWordCount: 0,
                updatedVocabularyCount: 0,
                auditMismatchCount: 0,
                auditFailureCount: 0,
                applyFailureCount: 0,
                failures: []
            )
        }

        let tasks = await prepareTasks(
            from: vocabularies,
            cutoffDate: cutoffDate,
            failures: &failures,
            onProgress: onProgress
        )

        var regeneratedWordCount = 0
        for (index, task) in tasks.enumerated() {
            onProgress("word 재생성 중... (\(index + 1)/\(tasks.count)) \(task.lemma)")

            do {
                if let wordId = task.wordId {
                    let word = try await wordDataSource.word(id: wordId)
                    try await deleteLinkedWord(word)
                }

                let generation = try await autoGenerateWordSensesUseCase.autoGenerateSenses(
                    from: task.lemma,
                    onProgress: { message in
                        onProgress("word 재생성 중... (\(index + 1)/\(tasks.count)) \(task.lemma) - \(message)")
                    }
                )

                if let failureMessage = generation.generation.failures.first {
                    throw RegenerationError.autoGenerateFailed(message: failureMessage)
                }

                regeneratedWordCount += 1
            } catch {
                failures.append("\(task.lemma): \(error.localizedDescription)")
            }
        }

        let auditResult = await vocabularyLinkAuditUseCase.audit(
            vocabularies: vocabularies,
            onProgress: onProgress
        )
        let applyResult = await vocabularyLinkAuditUseCase.applyAuditResults(
            to: vocabularies,
            auditsByVocabularyId: auditResult.auditsByVocabularyId,
            onProgress: onProgress
        )

        return Result(
            totalVocabularyCount: vocabularies.count,
            resolvedWordCount: tasks.count,
            regeneratedWordCount: regeneratedWordCount,
            updatedVocabularyCount: applyResult.updatedCount,
            auditMismatchCount: auditResult.mismatchCount,
            auditFailureCount: auditResult.failureCount,
            applyFailureCount: applyResult.failureCount,
            failures: failures
        )
    }

    func fetchAllVocabulariesWithoutExamples(
        onProgress: (String) -> Void
    ) async throws -> [Vocabulary] {
        let pageSize = 600
        var offset = 0
        var output: [Vocabulary] = []

        while true {
            onProgress("예문 없는 vocabulary 조회 중... \(offset)")
            let page = try await vocabularyDataSource.listWithoutExamples(limit: pageSize, offset: offset)
            output.append(contentsOf: page)

            guard page.count == pageSize else { break }
            offset += page.count
        }

        return output
    }

    private func prepareTasks(
        from vocabularies: [Vocabulary],
        cutoffDate: Date,
        failures: inout [String],
        onProgress: (String) -> Void
    ) async -> [RegenerationTask] {
        var tasks: [RegenerationTask] = []
        var seenTaskKeys: Set<String> = []

        for (index, vocabulary) in vocabularies.enumerated() {
            onProgress("연결 word 조회 중... (\(index + 1)/\(vocabularies.count)) \(vocabulary.text)")

            do {
                if let word = try await resolveLinkedWord(for: vocabulary) {
                    let isEligibleByDate = word.createdAt.map { $0 < cutoffDate } ?? false
                    guard isEligibleByDate else { continue }

                    let lemma = word.lemma.trimmed
                    guard !lemma.isEmpty else {
                        throw RegenerationError.emptyLemma(wordId: word.id)
                    }

                    let taskKey = "word:\(word.id)"
                    guard seenTaskKeys.insert(taskKey).inserted else { continue }

                    tasks.append(
                        RegenerationTask(
                            wordId: word.id,
                            lemma: lemma
                        )
                    )
                } else {
                    let lemma = vocabulary.text.trimmed
                    guard !lemma.isEmpty else {
                        throw RegenerationError.noLinkedWord(vocabularyText: vocabulary.text)
                    }

                    let taskKey = "lemma:\(lemma.lowercased())"
                    guard seenTaskKeys.insert(taskKey).inserted else { continue }

                    tasks.append(
                        RegenerationTask(
                            wordId: nil,
                            lemma: lemma
                        )
                    )
                }
            } catch {
                failures.append("\(vocabulary.text): \(error.localizedDescription)")
            }
        }

        return tasks
    }

    func resolveLinkedWord(
        for vocabulary: Vocabulary
    ) async throws -> WordRead? {
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

        return nil
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
}
