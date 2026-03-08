//
//  PhraseDataSource.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import Foundation

final class PhraseDataSource {
    static let shared = PhraseDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Phrase 목록 조회 (GET /phrases)
    func listPhrases(
        q: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [PhraseRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let q, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(.init(name: "q", value: q.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return try await api.request(
            "GET",
            "admin/phrases",
            query: query,
            as: [PhraseRead].self
        )
    }

    // MARK: - Phrase 생성 (POST /phrases)
    @discardableResult
    func createPhrase(
        text: String,
        lessonTargetId: Int? = nil,
        translations: [PhraseTranslationSchema]? = nil
    ) async throws -> PhraseRead {
        let body = PhraseCreate(
            text: text,
            lessonTargetId: lessonTargetId,
            translations: translations
        )
        return try await api.request(
            "POST",
            "admin/phrases",
            jsonBody: body.toDict(),
            as: PhraseRead.self
        )
    }

    // MARK: - Phrase 단건 조회 (GET /phrases/{phrase_id})
    func phrase(id: Int) async throws -> PhraseRead {
        try await api.request(
            "GET",
            "admin/phrases/\(id)",
            as: PhraseRead.self
        )
    }

    // MARK: - Phrase 수정 (PUT /phrases/{phrase_id})
    @discardableResult
    func updatePhrase(
        id: Int,
        text: String? = nil,
        lessonTargetId: Int? = nil,
        translations: [PhraseTranslationSchema]? = nil
    ) async throws -> PhraseRead {
        let body = PhraseUpdate(
            text: text,
            lessonTargetId: lessonTargetId,
            translations: translations
        )
        return try await api.request(
            "PUT",
            "admin/phrases/\(id)",
            jsonBody: body.toDict(),
            as: PhraseRead.self
        )
    }

    // MARK: - Phrase 삭제 (DELETE /phrases/{phrase_id})
    func deletePhrase(id: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/phrases/\(id)",
            as: Empty.self
        )
    }
}

