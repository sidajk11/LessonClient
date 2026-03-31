//
//  SentenceVocabularyAnalysisUseCase.swift
//  LessonClient
//
//  Created by ym on 3/30/26.
//

import Foundation

// 문장이나 token 목록을 기준으로 vocabulary 연결 상태와 최고 unit을 분석합니다.
final class SentenceVocabularyAnalysisUseCase {
    struct HighestUnitInfo {
        let unit: Int
        let vocabularyText: String
    }

    static let shared = SentenceVocabularyAnalysisUseCase()

    private let generateTokensUseCase = GenerateTokensUseCase.shared
    private let wordUseCase = WordUseCase.shared
    private let lessonDataSource = LessonDataSource.shared

    private init() {}
}

extension SentenceVocabularyAnalysisUseCase {
    /// 문장 안에서 가장 높은 lesson unit만 간단히 구합니다.
    func highestUnit(in sentence: String) async throws -> Int? {
        try await highestUnitInfo(in: sentence)?.unit
    }

    /// 문장 안에서 가장 높은 lesson unit과 해당 단어를 함께 구합니다.
    func highestUnitInfo(in sentence: String) async throws -> HighestUnitInfo? {
        let drafts = try await generateTokensUseCase.buildTokenDrafts(from: sentence)
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
        let drafts = try await generateTokensUseCase.buildTokenDrafts(from: sentence)
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
}

private extension SentenceVocabularyAnalysisUseCase {
    /// surface 목록으로 최고 unit 정보를 계산하는 내부 공용 헬퍼입니다.
    func highestUnitInfo(fromSurfaces surfaces: [String]) async throws -> HighestUnitInfo? {
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
    func resolveVocabulary(
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
