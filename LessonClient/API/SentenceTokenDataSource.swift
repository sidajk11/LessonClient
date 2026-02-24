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

    func listSentenceTokens(
        exampleId: Int? = nil,
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

    func deleteSentenceToken(id: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/sentence-tokens/\(id)",
            as: Empty.self
        )
    }
}
