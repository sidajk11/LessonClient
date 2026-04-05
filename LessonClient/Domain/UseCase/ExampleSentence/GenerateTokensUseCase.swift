//
//  GenerateTokensUseCase.swift
//  LessonClient
//
//  Created by ym on 3/18/26.
//

import Foundation

// 예문 문장을 token 초안과 서버 token 레코드로 만드는 흐름을 담당합니다.
final class GenerateTokensUseCase {
    struct TokenDraft {
        let surface: String
        let phraseId: Int?
        let formId: Int?
    }

    private enum GenerateTokensUseCaseError: LocalizedError {
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

    static let shared = GenerateTokensUseCase()

    private let tokenPhraseMerger = SentenceTokenPhraseMerger()
    private let tokenRangesUseCase = TokenRangesUseCase.shared
    private let sentenceTokenDataSource = SentenceTokenDataSource.shared

    /// 문장을 token 초안 목록으로 만들고 필요하면 phrase 정보를 채웁니다.
    func buildTokenDrafts(
        from sentence: String,
        includePhrases: Bool = true
    ) async throws -> [TokenDraft] {
        let trimmedSentence = sentence.trimmed
        guard !trimmedSentence.isEmpty else {
            throw GenerateTokensUseCaseError.emptySentence
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
        guard !mergedDrafts.isEmpty else {
            throw GenerateTokensUseCaseError.noTokenizableSentence
        }

        return mergedDrafts
    }

    /// 문장 하나를 서버 token 레코드들로 생성합니다.
    @discardableResult
    func createTokensFromSentence(
        exampleSentenceId: Int,
        sentence: String,
        includePhrases: Bool = true
    ) async throws -> [SentenceTokenRead] {
        let drafts = try await buildTokenDrafts(from: sentence, includePhrases: includePhrases)
        let rangeDrafts = try tokenRangesUseCase.buildTokenRanges(
            from: sentence,
            surfaces: drafts.map(\.surface)
        )
        var created: [SentenceTokenRead] = []
        created.reserveCapacity(drafts.count)

        for (idx, draft) in drafts.enumerated() {
            let rangeDraft = rangeDrafts[idx]
            let token = try await sentenceTokenDataSource.createSentenceToken(
                exampleSentenceId: exampleSentenceId,
                tokenIndex: idx,
                surface: draft.surface,
                phraseId: draft.phraseId,
                formId: nil,
                startIndex: rangeDraft.startIndex,
                endIndex: rangeDraft.endIndex
            )
            created.append(token)
        }

        return created
    }
}
