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

actor VocabularyLinkAuditor {
    private var lessonLevelByLessonId: [Int: Int] = [:]
    private let phraseDataSource = PhraseDataSource.shared
    private let wordFormDataSource = WordFormDataSource.shared
    private let wordDataSource = WordDataSource.shared

    func audit(vocabulary: Vocabulary) async throws -> VocabularyLinkAuditResult {
        let text = vocabulary.text.trimmed
        let normalizedText = normalizedLookupKey(for: text)
        
        // phrase/form은 text exact-match 성격으로 가장 먼저 매칭되는 항목을 기대값으로 사용합니다.
        let phraseRows = try await phraseDataSource.listPhrases(q: text, limit: 20)
        let expectedPhraseId = phraseRows.first {
            matches($0.text, normalizedWord: normalizedText) || matches($0.normalized, normalizedWord: normalizedText)
        }?.id

        let formRows = try await wordFormDataSource.listWordFormsByForm(form: text, limit: 50)
        let expectedForm = formRows.first {
            matches($0.form, normalizedWord: normalizedText)
        }
        let expectedFormId = expectedForm?.id

        let cefr = vocabulary.cefr
        let expectedSenseId: Int?
        // form으로 word를 찾을 수 있으면 lemma 기준 sense 조회를 한 번 더 보완합니다.
        let senseLemma: String?
        if let expectedForm,
           let word = try? await wordDataSource.word(id: expectedForm.wordId) {
            senseLemma = word.lemma
        } else {
            senseLemma = nil
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

    private func listWordSensesByLemmaAndCefr(lemma: String, cefr: String) async throws -> [WordSenseRead] {
        do {
            return try await wordDataSource.listWordSensesByLemmaAndCefr(
                lemma: lemma,
                cefr: cefr,
                limit: 100
            )
        } catch APIClient.APIError.http(let statusCode, _) where statusCode == 404 {
            return []
        }
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

    private func cefr(for vocabulary: Vocabulary) async throws -> String? {
        guard let lessonId = vocabulary.lessonId else { return nil }

        let level: Int
        if let cached = lessonLevelByLessonId[lessonId] {
            level = cached
        } else {
            // vocabulary 자체에 CEFR가 없어서 lesson.level을 CEFR로 환산해 사용합니다.
            let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
            level = lesson.level
            lessonLevelByLessonId[lessonId] = level
        }

        return cefr(forLessonLevel: level)
    }

    private func cefr(forLessonLevel level: Int) -> String? {
        switch level {
        case 1: return "A1"
        case 2: return "A2"
        case 3: return "B1"
        case 4: return "B2"
        case 5: return "C1"
        case 6: return "C2"
        default: return nil
        }
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
