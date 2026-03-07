//
//  SentenceTokenDataSource.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation

final class SentenceTokenDataSource {
    static let shared = SentenceTokenDataSource()
    private let api = APIClient.shared
    private init() {}

    private func jsonNullable<T>(_ value: T?) -> Any {
        if let value { return value }
        return NSNull()
    }

    func listSentenceTokens(
        exampleId: Int? = nil,
        phraseId: Int? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [SentenceTokenRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let exampleId { query.append(.init(name: "example_id", value: String(exampleId))) }
        if let phraseId { query.append(.init(name: "phrase_id", value: String(phraseId))) }
        if let wordId { query.append(.init(name: "word_id", value: String(wordId))) }
        if let formId { query.append(.init(name: "form_id", value: String(formId))) }
        if let senseId { query.append(.init(name: "sense_id", value: String(senseId))) }

        return try await api.request(
            "GET",
            "admin/sentence-tokens",
            query: query,
            as: [SentenceTokenRead].self
        )
    }

    @discardableResult
    func createSentenceToken(
        exampleId: Int,
        tokenIndex: Int,
        surface: String,
        phraseId: Int? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        pos: String? = nil,
        startIndex: Int? = nil,
        endIndex: Int? = nil
    ) async throws -> SentenceTokenRead {
        let body = SentenceTokenCreate(
            exampleId: exampleId,
            tokenIndex: tokenIndex,
            surface: surface,
            phraseId: phraseId,
            wordId: wordId,
            formId: formId,
            senseId: senseId,
            pos: pos,
            startIndex: startIndex,
            endIndex: endIndex
        )
        return try await api.request(
            "POST",
            "admin/sentence-tokens",
            jsonBody: body.toDict(),
            as: SentenceTokenRead.self
        )
    }

    func sentenceToken(id: Int) async throws -> SentenceTokenRead {
        try await api.request(
            "GET",
            "admin/sentence-tokens/\(id)",
            as: SentenceTokenRead.self
        )
    }

    @discardableResult
    func updateSentenceToken(
        id: Int,
        exampleId: Int? = nil,
        tokenIndex: Int? = nil,
        surface: String? = nil,
        phraseId: Int? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        pos: String? = nil,
        startIndex: Int? = nil,
        endIndex: Int? = nil
    ) async throws -> SentenceTokenRead {
        let body = SentenceTokenUpdate(
            exampleId: exampleId,
            tokenIndex: tokenIndex,
            surface: surface,
            phraseId: phraseId,
            wordId: wordId,
            formId: formId,
            senseId: senseId,
            pos: pos,
            startIndex: startIndex,
            endIndex: endIndex
        )
        return try await api.request(
            "PUT",
            "admin/sentence-tokens/\(id)",
            jsonBody: body.toDict(),
            as: SentenceTokenRead.self
        )
    }

    /// Replace token fields with nullable payload (`null` 포함 PUT).
    /// recreateTokensFromSentence 같은 전체 재계산 흐름에서 사용.
    @discardableResult
    func replaceSentenceToken(
        id: Int,
        exampleId: Int,
        tokenIndex: Int,
        surface: String,
        phraseId: Int? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        pos: String? = nil,
        startIndex: Int? = nil,
        endIndex: Int? = nil
    ) async throws -> SentenceTokenRead {
        let body: [String: Any] = [
            "example_id": exampleId,
            "token_index": tokenIndex,
            "surface": surface,
            "phrase_id": jsonNullable(phraseId),
            "word_id": jsonNullable(wordId),
            "form_id": jsonNullable(formId),
            "sense_id": jsonNullable(senseId),
            "pos": jsonNullable(pos),
            "start_index": jsonNullable(startIndex),
            "end_index": jsonNullable(endIndex)
        ]
        return try await api.request(
            "PUT",
            "admin/sentence-tokens/\(id)",
            jsonBody: body,
            as: SentenceTokenRead.self
        )
    }

    func deleteSentenceToken(id: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/sentence-tokens/\(id)",
            as: Empty.self
        )
    }

    @discardableResult
    func upsertSentenceTokenTranslation(
        tokenId: Int,
        lang: String,
        text: String
    ) async throws -> SentenceTokenRead {
        let body = SentenceTokenTranslationCreate(lang: lang, text: text)
        return try await api.request(
            "PUT",
            "admin/sentence-tokens/\(tokenId)/translations",
            jsonBody: body.toDict(),
            as: SentenceTokenRead.self
        )
    }
}
