//
//  TokenRangesUseCase.swift
//  LessonClient
//
//  Created by ym on 3/30/26.
//

import Foundation

// token surface 순서를 기준으로 문장 내 start/end range를 계산합니다.
final class TokenRangesUseCase {
    struct TokenRangeDraft {
        let tokenIndex: Int
        let startIndex: Int
        let endIndex: Int
    }

    struct TokenRangeUpdate {
        let tokenId: Int
        let startIndex: Int
        let endIndex: Int
    }

    private enum TokenRangesUseCaseError: LocalizedError {
        case emptySentence
        case noTokenizableSentence
        case tokenRangeMismatch(String)

        var errorDescription: String? {
            switch self {
            case .emptySentence:
                return "문장을 입력해 주세요."
            case .noTokenizableSentence:
                return "토큰화할 문장이 없습니다."
            case .tokenRangeMismatch(let surface):
                return "문장과 token surface를 맞출 수 없습니다: \(surface)"
            }
        }
    }

    static let shared = TokenRangesUseCase()

    private init() {}
}

extension TokenRangesUseCase {
    /// 현재 token surface 순서를 기준으로 문장 내 start/end index를 계산합니다.
    func buildTokenRanges(from sentence: String, surfaces: [String]) throws -> [TokenRangeDraft] {
        guard !sentence.trimmed.isEmpty else {
            throw TokenRangesUseCaseError.emptySentence
        }
        guard !surfaces.isEmpty else {
            throw TokenRangesUseCaseError.noTokenizableSentence
        }

        let nsSentence = sentence as NSString
        var cursor = 0
        var output: [TokenRangeDraft] = []
        output.reserveCapacity(surfaces.count)

        for (idx, rawSurface) in surfaces.enumerated() {
            let surface = rawSurface.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !surface.isEmpty else {
                throw TokenRangesUseCaseError.tokenRangeMismatch(rawSurface)
            }

            let searchRange = NSRange(location: cursor, length: nsSentence.length - cursor)
            let foundRange = nsSentence.range(of: surface, options: [], range: searchRange)
            guard foundRange.location != NSNotFound else {
                throw TokenRangesUseCaseError.tokenRangeMismatch(surface)
            }

            // token 사이에는 공백만 허용해서 surface 조합이 문장을 온전히 덮는지 확인합니다.
            let gapRange = NSRange(location: cursor, length: foundRange.location - cursor)
            let gapText = gapRange.length > 0 ? nsSentence.substring(with: gapRange) : ""
            guard gapText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TokenRangesUseCaseError.tokenRangeMismatch(surface)
            }

            output.append(
                .init(
                    tokenIndex: idx,
                    startIndex: foundRange.location,
                    endIndex: foundRange.location + foundRange.length
                )
            )
            cursor = foundRange.location + foundRange.length
        }

        let trailingText = cursor < nsSentence.length ? nsSentence.substring(from: cursor) : ""
        guard trailingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TokenRangesUseCaseError.tokenRangeMismatch(trailingText)
        }

        return output
    }

    /// 기존 token id에 맞춰 start/end index 업데이트 payload를 만듭니다.
    func buildTokenRangeUpdates(sentence: String, tokens: [SentenceTokenRead]) throws -> [TokenRangeUpdate] {
        let sortedTokens = tokens.sorted(by: { $0.tokenIndex < $1.tokenIndex })
        let rangeDrafts = try buildTokenRanges(
            from: sentence,
            surfaces: sortedTokens.map(\.surface)
        )

        return zip(sortedTokens, rangeDrafts).map { token, rangeDraft in
            .init(
                tokenId: token.id,
                startIndex: rangeDraft.startIndex,
                endIndex: rangeDraft.endIndex
            )
        }
    }
}
