//
//  PronunciationDataSource.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation

final class PronunciationDataSource {
    static let shared = PronunciationDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Pronunciation 목록 조회 (GET /pronunciations)
    func listPronunciations(
        wordId: Int? = nil,
        senseId: Int? = nil,
        dialect: Dialect? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [PronunciationRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        if let wordId { query.append(.init(name: "word_id", value: String(wordId))) }
        if let senseId { query.append(.init(name: "sense_id", value: String(senseId))) }
        if let dialect { query.append(.init(name: "dialect", value: dialect.rawValue)) }

        return try await api.request(
            "GET",
            "admin/pronunciations",
            query: query,
            as: [PronunciationRead].self
        )
    }

    // MARK: - Pronunciation 생성 (POST /pronunciations)
    @discardableResult
    func createPronunciation(
        wordId: Int,
        senseId: Int? = nil,
        ipa: String,
        dialect: Dialect,
        audioUrl: String? = nil,
        ttsProvider: String? = nil,
        isPrimary: Bool = false
    ) async throws -> PronunciationRead {
        let body = PronunciationCreate(
            wordId: wordId,
            senseId: senseId,
            ipa: ipa,
            dialect: dialect,
            audioUrl: audioUrl,
            ttsProvider: ttsProvider,
            isPrimary: isPrimary
        )

        return try await api.request(
            "POST",
            "admin/pronunciations",
            jsonBody: body.toDict(),
            as: PronunciationRead.self
        )
    }

    // MARK: - Pronunciation 단건 조회 (GET /pronunciations/{pronunciation_id})
    func pronunciation(id pronunciationId: Int) async throws -> PronunciationRead {
        try await api.request(
            "GET",
            "admin/pronunciations/\(pronunciationId)",
            as: PronunciationRead.self
        )
    }

    // MARK: - Pronunciation 수정 (PUT /pronunciations/{pronunciation_id})
    @discardableResult
    func updatePronunciation(
        id pronunciationId: Int,
        wordId: Int? = nil,
        senseId: Int? = nil,
        ipa: String? = nil,
        dialect: Dialect? = nil,
        audioUrl: String? = nil,
        ttsProvider: String? = nil,
        isPrimary: Bool? = nil
    ) async throws -> PronunciationRead {
        let body = PronunciationUpdate(
            wordId: wordId,
            senseId: senseId,
            ipa: ipa,
            dialect: dialect,
            audioUrl: audioUrl,
            ttsProvider: ttsProvider,
            isPrimary: isPrimary
        )

        return try await api.request(
            "PUT",
            "admin/pronunciations/\(pronunciationId)",
            jsonBody: body.toDict(),
            as: PronunciationRead.self
        )
    }

    // MARK: - Pronunciation 삭제 (DELETE /pronunciations/{pronunciation_id})
    func deletePronunciation(id pronunciationId: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/pronunciations/\(pronunciationId)",
            as: Empty.self
        )
    }
}
