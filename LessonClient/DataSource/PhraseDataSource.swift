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
    private let cache = PhraseMemoryStore()
    private init() {}

    /// 전체 phrase를 서버에서 가져와 메모리 캐시에 적재합니다.
    @discardableResult
    func loadPhases(pageSize: Int = 200) async throws -> [PhraseRead] {
        if let cached = await cache.allPhrases() {
            return cached
        }

        let safePageSize = min(max(pageSize, 1), 200)
        var allRows: [PhraseRead] = []
        var offset = 0

        while true {
            let rows = try await requestPhrasesFromServer(
                q: nil,
                limit: safePageSize,
                offset: offset
            )
            allRows.append(contentsOf: rows)

            guard rows.count == safePageSize else { break }
            offset += rows.count
        }

        await cache.replaceAll(with: allRows)
        return allRows
    }

    /// 메모리 캐시에 적재된 phrase만 조회합니다.
    func cachedPhrases(
        q: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async -> [PhraseRead] {
        let trimmedQ = q?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeQ = (trimmedQ?.isEmpty == false) ? trimmedQ : nil
        return await cache.listPhrases(q: safeQ, limit: limit, offset: offset) ?? []
    }

    // MARK: - Phrase 목록 조회 (GET /phrases)
    func listPhrases(
        q: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [PhraseRead] {
        let trimmedQ = q?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeQ = (trimmedQ?.isEmpty == false) ? trimmedQ : nil

        if let cached = await cache.listPhrases(
            q: safeQ,
            limit: limit,
            offset: offset
        ) {
            return cached
        }

        return try await requestPhrasesFromServer(q: safeQ, limit: limit, offset: offset)
    }

    // MARK: - Phrase 생성 (POST /phrases)
    @discardableResult
    func createPhrase(
        text: String,
        translations: [PhraseTranslationSchema]? = nil
    ) async throws -> PhraseRead {
        let body = PhraseCreate(
            text: text,
            translations: translations
        )
        let created = try await api.request(
            "POST",
            "admin/phrases",
            jsonBody: body.toDict(),
            as: PhraseRead.self
        )
        await cache.upsert(created)
        return created
    }

    // MARK: - Phrase 단건 조회 (GET /phrases/{phrase_id})
    func phrase(id: Int) async throws -> PhraseRead {
        if let cached = await cache.phrase(id: id) {
            return cached
        }

        let row = try await api.request(
            "GET",
            "admin/phrases/\(id)",
            as: PhraseRead.self
        )
        await cache.upsert(row)
        return row
    }

    // MARK: - Phrase 수정 (PUT /phrases/{phrase_id})
    @discardableResult
    func updatePhrase(
        id: Int,
        text: String? = nil,
        translations: [PhraseTranslationSchema]? = nil
    ) async throws -> PhraseRead {
        let body = PhraseUpdate(
            text: text,
            translations: translations
        )
        let updated = try await api.request(
            "PUT",
            "admin/phrases/\(id)",
            jsonBody: body.toDict(),
            as: PhraseRead.self
        )
        await cache.upsert(updated)
        return updated
    }

    // MARK: - Phrase 삭제 (DELETE /phrases/{phrase_id})
    func deletePhrase(id: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/phrases/\(id)",
            as: Empty.self
        )
        await cache.remove(id: id)
    }

    private func requestPhrasesFromServer(
        q: String?,
        limit: Int,
        offset: Int
    ) async throws -> [PhraseRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let q, !q.isEmpty {
            query.append(.init(name: "q", value: q))
        }

        return try await api.request(
            "GET",
            "admin/phrases",
            query: query,
            as: [PhraseRead].self
        )
    }
}

private actor PhraseMemoryStore {
    private var phrasesById: [Int: PhraseRead] = [:]
    private var orderedIds: [Int] = []
    private var hasLoadedAllPhrases = false

    func replaceAll(with phrases: [PhraseRead]) {
        phrasesById = Dictionary(uniqueKeysWithValues: phrases.map { ($0.id, $0) })
        orderedIds = phrases.map(\.id)
        hasLoadedAllPhrases = true
    }

    func phrase(id: Int) -> PhraseRead? {
        phrasesById[id]
    }

    func allPhrases() -> [PhraseRead]? {
        guard hasLoadedAllPhrases else { return nil }
        return orderedIds.compactMap { phrasesById[$0] }
    }

    func upsert(_ phrase: PhraseRead) {
        let isExisting = phrasesById.updateValue(phrase, forKey: phrase.id) != nil
        guard !isExisting else { return }

        if hasLoadedAllPhrases {
            orderedIds.insert(phrase.id, at: 0)
        } else {
            orderedIds.append(phrase.id)
        }
    }

    func remove(id: Int) {
        phrasesById.removeValue(forKey: id)
        orderedIds.removeAll { $0 == id }
    }

    func listPhrases(
        q: String?,
        limit: Int,
        offset: Int
    ) -> [PhraseRead]? {
        guard hasLoadedAllPhrases else { return nil }

        let safeLimit = min(max(limit, 1), 200)
        let safeOffset = max(offset, 0)
        let query = q?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = orderedIds
            .compactMap { phrasesById[$0] }
            .filter { phrase in
                guard let query, !query.isEmpty else { return true }
                return matches(phrase, query: query)
            }

        guard safeOffset < filtered.count else { return [] }
        return Array(filtered.dropFirst(safeOffset).prefix(safeLimit))
    }

    private func matches(_ phrase: PhraseRead, query: String) -> Bool {
        if phrase.text.lowercased().contains(query) { return true }
        if phrase.normalized.lowercased().contains(query) { return true }
        if phrase.translations.contains(where: { $0.text.lowercased().contains(query) }) { return true }
        return false
    }
}
