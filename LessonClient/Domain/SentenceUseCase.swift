//
//  SentenceUseCase.swift
//  LessonClient
//
//  Created by ym on 3/18/26.
//

import Foundation

final class SentenceUseCase {
    struct TokenDraft {
        let surface: String
        let phraseId: Int?
        let formId: Int?
    }

    struct HighestUnitInfo {
        let unit: Int
        let vocabularyText: String
    }

    private enum SentenceUseCaseError: LocalizedError {
        case emptySentence
        case noTokenizableSentence

        var errorDescription: String? {
            switch self {
            case .emptySentence:
                return "문장을 입력해 주세요."
            case .noTokenizableSentence:
                return "토큰화할 문장이 없습니다."
            }
        }
    }

    static let shared = SentenceUseCase()

    private let tokenPhraseMerger = SentenceTokenPhraseMerger()
    private let formDataSource = WordFormDataSource.shared
    private let sentenceTokenDataSource = SentenceTokenDataSource.shared
    private let wordUseCase = WordUseCase.shared
    private let lessonDataSource = LessonDataSource.shared

    /// 문장을 token 초안 목록으로 만들고 필요하면 phrase/form 정보를 채웁니다.
    func buildTokenDrafts(
        from sentence: String,
        includePhrases: Bool = true
    ) async throws -> [TokenDraft] {
        let trimmedSentence = sentence.trimmed
        guard !trimmedSentence.isEmpty else {
            throw SentenceUseCaseError.emptySentence
        }

        let rawParts = trimmedSentence.tokenize()
        let mergedDrafts: [TokenDraft]
        if includePhrases {
            let mergedTokens = await tokenPhraseMerger.merge(tokens: rawParts)
            mergedDrafts = mergedTokens.map {
                TokenDraft(surface: $0.surface, phraseId: $0.phraseId, formId: nil)
            }
        } else {
            mergedDrafts = rawParts.map {
                TokenDraft(surface: $0, phraseId: nil, formId: nil)
            }
        }
        let drafts = try await fillFormIds(in: mergedDrafts)
        guard !drafts.isEmpty else {
            throw SentenceUseCaseError.noTokenizableSentence
        }

        return drafts
    }

    /// 문장 하나를 서버 token 레코드들로 생성합니다.
    @discardableResult
    func createTokensFromSentence(
        exampleId: Int,
        sentence: String,
        includePhrases: Bool = true
    ) async throws -> [SentenceTokenRead] {
        let drafts = try await buildTokenDrafts(from: sentence, includePhrases: includePhrases)
        var created: [SentenceTokenRead] = []
        created.reserveCapacity(drafts.count)

        for (idx, draft) in drafts.enumerated() {
            let token = try await sentenceTokenDataSource.createSentenceToken(
                exampleId: exampleId,
                tokenIndex: idx,
                surface: draft.surface,
                phraseId: draft.phraseId,
                formId: draft.formId
            )
            created.append(token)
        }

        return created
    }

    /// 문장 안에서 가장 높은 lesson unit만 간단히 구합니다.
    func highestUnit(in sentence: String) async throws -> Int? {
        try await highestUnitInfo(in: sentence)?.unit
    }

    /// 문장 안에서 가장 높은 lesson unit과 해당 단어를 함께 구합니다.
    func highestUnitInfo(in sentence: String) async throws -> HighestUnitInfo? {
        let drafts = try await buildTokenDrafts(from: sentence)
        return try await highestUnitInfo(fromSurfaces: drafts.map(\.surface))
    }

    /// 이미 생성된 token 목록으로 최고 unit 정보를 계산합니다.
    func highestUnitInfo(tokens: [SentenceTokenRead]) async throws -> HighestUnitInfo? {
        var vocabularyByPhraseId: [Int: Vocabulary] = [:]
        var missingPhraseIds = Set<Int>()
        var vocabularyBySenseId: [Int: Vocabulary] = [:]
        var missingSenseIds = Set<Int>()
        var vocabularyByWordId: [Int: Vocabulary] = [:]
        var missingWordIds = Set<Int>()
        var lessonUnitCache: [Int: Int] = [:]
        var highestInfo: HighestUnitInfo?

        for token in tokens {
            let surface = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !surface.isEmpty, !punctuationSet.contains(surface) else { continue }

            let vocabulary = try await resolveVocabulary(
                for: token,
                vocabularyByPhraseId: &vocabularyByPhraseId,
                missingPhraseIds: &missingPhraseIds,
                vocabularyBySenseId: &vocabularyBySenseId,
                missingSenseIds: &missingSenseIds,
                vocabularyByWordId: &vocabularyByWordId,
                missingWordIds: &missingWordIds
            )

            guard let vocabulary, let lessonId = vocabulary.lessonId else { continue }

            let unit: Int
            if let cached = lessonUnitCache[lessonId] {
                unit = cached
            } else {
                let lesson = try await lessonDataSource.lesson(id: lessonId)
                unit = lesson.unit
                lessonUnitCache[lessonId] = unit
            }

            if highestInfo == nil || unit > highestInfo?.unit ?? Int.min {
                highestInfo = HighestUnitInfo(unit: unit, vocabularyText: vocabulary.text)
            }
        }

        return highestInfo
    }

    /// 문장 안에 vocabulary로 해석되지 않는 token이 있는지 검사합니다.
    func containsUnresolvableVocabulary(in sentence: String) async throws -> Bool {
        try await firstUnresolvableVocabulary(in: sentence) != nil
    }

    /// 문장 기준으로 첫 번째 미해결 vocabulary surface를 찾습니다.
    func firstUnresolvableVocabulary(in sentence: String) async throws -> String? {
        let drafts = try await buildTokenDrafts(from: sentence)
        var vocabularyCache: [String: Vocabulary] = [:]
        var missingVocabularyKeys = Set<String>()

        for draft in drafts {
            let surface = draft.surface.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !surface.isEmpty, !punctuationSet.contains(surface) else { continue }

            let key = surface.lowercased()
            if vocabularyCache[key] != nil {
                continue
            }
            if missingVocabularyKeys.contains(key) {
                return surface
            }

            let found = try await wordUseCase.findVocabulary(byEnglish: surface).first
            if let found {
                vocabularyCache[key] = found
            } else {
                missingVocabularyKeys.insert(key)
                return surface
            }
        }

        return nil
    }

    /// token 기준으로 첫 번째 미해결 vocabulary surface를 찾습니다.
    func firstUnresolvableVocabulary(tokens: [SentenceTokenRead]) async throws -> String? {
        var vocabularyByPhraseId: [Int: Vocabulary] = [:]
        var missingPhraseIds = Set<Int>()
        var vocabularyBySenseId: [Int: Vocabulary] = [:]
        var missingSenseIds = Set<Int>()
        var vocabularyByWordId: [Int: Vocabulary] = [:]
        var missingWordIds = Set<Int>()

        for token in tokens {
            let surface = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !surface.isEmpty, !punctuationSet.contains(surface) else { continue }

            let vocabulary = try await resolveVocabulary(
                for: token,
                vocabularyByPhraseId: &vocabularyByPhraseId,
                missingPhraseIds: &missingPhraseIds,
                vocabularyBySenseId: &vocabularyBySenseId,
                missingSenseIds: &missingSenseIds,
                vocabularyByWordId: &vocabularyByWordId,
                missingWordIds: &missingWordIds
            )
            if vocabulary == nil {
                return surface
            }
        }

        return nil
    }

    /// token 초안의 surface를 기준으로 form_id를 보강합니다.
    private func fillFormIds(in drafts: [TokenDraft]) async throws -> [TokenDraft] {
        var cache: [String: Int?] = [:]
        var output: [TokenDraft] = []
        output.reserveCapacity(drafts.count)

        for draft in drafts {
            let trimmed = draft.surface.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || punctuationSet.contains(trimmed) {
                output.append(draft)
                continue
            }

            let key = trimmed.lowercased()
            let formId: Int?
            if let cached = cache[key] {
                formId = cached
            } else {
                let rows = try await formDataSource.listWordFormsByForm(form: trimmed, limit: 50)
                let exact = rows.first(where: { $0.form.lowercased() == key })
                let picked = exact ?? rows.first
                formId = picked?.id
                cache[key] = formId
            }

            output.append(.init(surface: draft.surface, phraseId: draft.phraseId, formId: formId))
        }

        return output
    }

    /// surface 목록으로 최고 unit 정보를 계산하는 내부 공용 헬퍼입니다.
    private func highestUnitInfo(fromSurfaces surfaces: [String]) async throws -> HighestUnitInfo? {
        var vocabularyCache: [String: Vocabulary] = [:]
        var missingVocabularyKeys = Set<String>()
        var lessonUnitCache: [Int: Int] = [:]
        var highestInfo: HighestUnitInfo?

        for rawSurface in surfaces {
            let surface = rawSurface.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !surface.isEmpty, !punctuationSet.contains(surface) else { continue }

            let key = surface.lowercased()
            let vocabulary: Vocabulary?
            if let cached = vocabularyCache[key] {
                vocabulary = cached
            } else if missingVocabularyKeys.contains(key) {
                vocabulary = nil
            } else {
                let found = try await wordUseCase.findVocabulary(byEnglish: surface).first
                if let found {
                    vocabularyCache[key] = found
                } else {
                    missingVocabularyKeys.insert(key)
                }
                vocabulary = found
            }

            guard let lessonId = vocabulary?.lessonId else { continue }

            let unit: Int
            if let cached = lessonUnitCache[lessonId] {
                unit = cached
            } else {
                let lesson = try await lessonDataSource.lesson(id: lessonId)
                unit = lesson.unit
                lessonUnitCache[lessonId] = unit
            }

            if highestInfo == nil || unit > highestInfo?.unit ?? Int.min {
                highestInfo = HighestUnitInfo(unit: unit, vocabularyText: vocabulary?.text ?? surface)
            }
        }

        return highestInfo
    }

    /// token의 phrase_id, sense_id, word_id 순서로 연결된 vocabulary를 찾습니다.
    private func resolveVocabulary(
        for token: SentenceTokenRead,
        vocabularyByPhraseId: inout [Int: Vocabulary],
        missingPhraseIds: inout Set<Int>,
        vocabularyBySenseId: inout [Int: Vocabulary],
        missingSenseIds: inout Set<Int>,
        vocabularyByWordId: inout [Int: Vocabulary],
        missingWordIds: inout Set<Int>
    ) async throws -> Vocabulary? {
        if let phraseId = token.phraseId {
            if let cached = vocabularyByPhraseId[phraseId] {
                return cached
            }
            if !missingPhraseIds.contains(phraseId) {
                let found = try await wordUseCase.findVocabulary(phraseId: phraseId).first
                if let found {
                    vocabularyByPhraseId[phraseId] = found
                    return found
                }
                missingPhraseIds.insert(phraseId)
            }
        }

        if let senseId = token.senseId {
            if let cached = vocabularyBySenseId[senseId] {
                return cached
            }
            if !missingSenseIds.contains(senseId) {
                let found = try await wordUseCase.findVocabulary(senseId: senseId, formId: token.formId).first
                if let found {
                    vocabularyBySenseId[senseId] = found
                    return found
                }
                missingSenseIds.insert(senseId)
            }
        }

        if let wordId = token.sense?.wordId {
            if let cached = vocabularyByWordId[wordId] {
                return cached
            }
            if !missingWordIds.contains(wordId) {
                let found = try await wordUseCase.findVocabulary(wordId: wordId).first
                if let found {
                    vocabularyByWordId[wordId] = found
                    return found
                }
                missingWordIds.insert(wordId)
            }
        }

        return nil
    }
}
