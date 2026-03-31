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
    private let formDataSource = WordFormDataSource.shared
    private let sentenceTokenDataSource = SentenceTokenDataSource.shared

    /// 문장을 token 초안 목록으로 만들고 필요하면 phrase/form 정보를 채웁니다.
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
        let drafts = try await fillFormIds(in: mergedDrafts)
        guard !drafts.isEmpty else {
            throw GenerateTokensUseCaseError.noTokenizableSentence
        }

        return drafts
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
                formId: draft.formId,
                startIndex: rangeDraft.startIndex,
                endIndex: rangeDraft.endIndex
            )
            created.append(token)
        }

        return created
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
}
