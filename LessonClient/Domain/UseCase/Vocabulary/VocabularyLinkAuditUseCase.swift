import Foundation

/// 현재 vocabulary 연결값과 조회로 계산한 기대 연결값을 함께 보관합니다.
struct VocabularyLinkAuditResult {
    let currentPhraseId: Int?
    let currentFormId: Int?
    let currentSenseId: Int?
    let expectedPhraseId: Int?
    let expectedFormId: Int?
    let expectedSenseId: Int?
    let cefr: String?

    var requiresSenseFix: Bool {
        currentPhraseId != expectedPhraseId ||
        currentFormId != expectedFormId ||
        currentSenseId != expectedSenseId
    }
}

struct VocabularyLinkAuditBatchResult {
    let auditsByVocabularyId: [Int: VocabularyLinkAuditResult]
    let failureMessagesByVocabularyId: [Int: String]
    let mismatchCount: Int
    let failureCount: Int
}

struct VocabularyLinkApplyBatchResult {
    let updatedVocabulariesById: [Int: Vocabulary]
    let auditsByVocabularyId: [Int: VocabularyLinkAuditResult]
    let updatedCount: Int
    let failureCount: Int
}

actor VocabularyLinkAuditor {
    private let phraseDataSource = PhraseDataSource.shared
    private let wordFormDataSource = WordFormDataSource.shared
    private let wordDataSource = WordDataSource.shared

    func audit(vocabulary: Vocabulary) async throws -> VocabularyLinkAuditResult {
        let text = vocabulary.text.trimmed
        let normalizedText = normalizedLookupKey(for: text)

        let phraseRows = try await phraseDataSource.listPhrases(q: text, limit: 20)
        let expectedPhraseId = phraseRows.first {
            matches($0.text, normalizedWord: normalizedText) || matches($0.normalized, normalizedWord: normalizedText)
        }?.id

        let formRows = try await wordFormDataSource.listWordFormsByForm(form: text, limit: 50)
        let expectedForm = formRows.first {
            matches($0.form, normalizedWord: normalizedText)
        }
        var expectedFormId = expectedForm?.id

        let cefr = vocabulary.cefr
        let expectedSenseId: Int?
        var senseLemma: String?
        if let expectedForm,
           let word = try? await wordDataSource.word(id: expectedForm.wordId) {
            senseLemma = word.lemma
        } else {
            senseLemma = nil
        }

        if !vocabulary.isForm {
            senseLemma = nil
            expectedFormId = nil
        }

        let senseRows = try await listWordByLemma(lemma: senseLemma ?? text)?.senses ?? []
        expectedSenseId = preferredSense(from: senseRows)?.id

        return VocabularyLinkAuditResult(
            currentPhraseId: vocabulary.phraseId,
            currentFormId: vocabulary.formId,
            currentSenseId: vocabulary.senseId,
            expectedPhraseId: expectedPhraseId,
            expectedFormId: expectedFormId,
            expectedSenseId: expectedSenseId,
            cefr: cefr
        )
    }

    private func listWordByLemma(lemma: String) async throws -> WordRead? {
        do {
            return try await wordDataSource.getWord(word: lemma)
        } catch APIClient.APIError.http(let statusCode, _) where statusCode == 404 {
            return nil
        }
    }

    private func preferredSense(from senses: [WordSenseRead]) -> WordSenseRead? {
        senses.min { lhs, rhs in
            compareSenseCode(lhs.senseCode, rhs.senseCode) == .orderedAscending
        }
    }

    private func compareSenseCode(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsNumber = Int(lhs.drop { !$0.isNumber })
        let rhsNumber = Int(rhs.drop { !$0.isNumber })

        if let lhsNumber, let rhsNumber, lhsNumber != rhsNumber {
            return lhsNumber < rhsNumber ? .orderedAscending : .orderedDescending
        }

        return lhs.localizedStandardCompare(rhs)
    }

    private func normalizedLookupKey(for text: String) -> String {
        text
            .replacingOccurrences(of: "’", with: "'")
            .trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func matches(_ value: String, normalizedWord: String) -> Bool {
        normalizedLookupKey(for: value) == normalizedWord
    }
}

@MainActor
final class VocabularyLinkAuditUseCase {
    static let shared = VocabularyLinkAuditUseCase()

    private let vocabularyDataSource = VocabularyDataSource.shared
    private let linkAuditor = VocabularyLinkAuditor()

    private init() {}

    func audit(
        vocabularies: [Vocabulary],
        onProgress: (String) -> Void = { _ in }
    ) async -> VocabularyLinkAuditBatchResult {
        var auditResults: [Int: VocabularyLinkAuditResult] = [:]
        var failureMessages: [Int: String] = [:]
        var mismatchCount = 0
        var failureCount = 0

        for (index, vocabulary) in vocabularies.enumerated() {
            onProgress("연결 검사 중... (\(index + 1)/\(vocabularies.count)) \(vocabulary.text)")

            do {
                let result = try await linkAuditor.audit(vocabulary: vocabulary)
                auditResults[vocabulary.id] = result
                if result.requiresSenseFix {
                    mismatchCount += 1
                }
            } catch {
                failureCount += 1
                failureMessages[vocabulary.id] = (error as NSError).localizedDescription
            }
        }

        return VocabularyLinkAuditBatchResult(
            auditsByVocabularyId: auditResults,
            failureMessagesByVocabularyId: failureMessages,
            mismatchCount: mismatchCount,
            failureCount: failureCount
        )
    }

    func applyAuditResults(
        to vocabularies: [Vocabulary],
        auditsByVocabularyId: [Int: VocabularyLinkAuditResult],
        onProgress: (String) -> Void = { _ in }
    ) async -> VocabularyLinkApplyBatchResult {
        let targetItems = vocabularies.compactMap { vocabulary -> (Vocabulary, VocabularyLinkAuditResult)? in
            guard let audit = auditsByVocabularyId[vocabulary.id], audit.requiresSenseFix else {
                return nil
            }
            return (vocabulary, audit)
        }

        var updatedVocabulariesById: [Int: Vocabulary] = [:]
        var refreshedAuditsByVocabularyId: [Int: VocabularyLinkAuditResult] = [:]
        var updatedCount = 0
        var failureCount = 0

        for (index, entry) in targetItems.enumerated() {
            let vocabulary = entry.0
            let audit = entry.1

            onProgress("검사 결과 적용 중... (\(index + 1)/\(targetItems.count)) \(vocabulary.text)")

            do {
                let updated = try await vocabularyDataSource.replaceVocabulary(
                    id: vocabulary.id,
                    text: vocabulary.text,
                    lessonId: vocabulary.lessonId,
                    formId: audit.expectedFormId,
                    senseId: audit.expectedSenseId,
                    phraseId: audit.expectedPhraseId,
                    exampleExercise: vocabulary.exampleExercise,
                    vocabularyExercise: vocabulary.vocabularyExercise,
                    isForm: vocabulary.isForm,
                    translations: vocabulary.translations
                )

                updatedVocabulariesById[updated.id] = updated
                refreshedAuditsByVocabularyId[updated.id] = VocabularyLinkAuditResult(
                    currentPhraseId: updated.phraseId,
                    currentFormId: updated.formId,
                    currentSenseId: updated.senseId,
                    expectedPhraseId: audit.expectedPhraseId,
                    expectedFormId: audit.expectedFormId,
                    expectedSenseId: audit.expectedSenseId,
                    cefr: audit.cefr
                )
                updatedCount += 1
            } catch {
                failureCount += 1
            }
        }

        return VocabularyLinkApplyBatchResult(
            updatedVocabulariesById: updatedVocabulariesById,
            auditsByVocabularyId: refreshedAuditsByVocabularyId,
            updatedCount: updatedCount,
            failureCount: failureCount
        )
    }
}
