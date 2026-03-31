//
//  ExampleSentenceDataSource.swift
//  LessonClient
//
//  Created by Codex on 3/30/26.
//

import Foundation

final class ExampleSentenceDataSource {
    static let shared = ExampleSentenceDataSource()
    private let api = APIClient.shared

    private init() {}
}

extension ExampleSentenceDataSource {
    // example_sentence 목록을 조회합니다.
    func listExampleSentences(
        exampleId: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ExampleSentence] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let exampleId {
            query.append(.init(name: "example_id", value: String(exampleId)))
        }

        return try await api.request(
            "GET",
            "admin/example-sentences",
            query: query,
            as: [ExampleSentence].self
        )
    }

    // example_sentence를 검색합니다.
    func searchExampleSentences(
        q: String = "",
        exampleId: Int? = nil,
        level: Int? = nil,
        unit: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ExampleSentence] {
        var query: [URLQueryItem] = [
            .init(name: "q", value: q.trimmingCharacters(in: .whitespacesAndNewlines)),
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let exampleId {
            query.append(.init(name: "example_id", value: String(exampleId)))
        }
        if let level {
            query.append(.init(name: "level", value: String(level)))
        }
        if let unit {
            query.append(.init(name: "unit", value: String(unit)))
        }

        return try await api.request(
            "GET",
            "admin/example-sentences/search",
            query: query,
            as: [ExampleSentence].self
        )
    }

    // sentence가 2개 이상인 example_sentence 목록을 조회합니다.
    func listMultiSentenceExampleSentences(
        exampleId: Int? = nil,
        level: Int? = nil,
        unit: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ExampleSentence] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let exampleId {
            query.append(.init(name: "example_id", value: String(exampleId)))
        }
        if let level {
            query.append(.init(name: "level", value: String(level)))
        }
        if let unit {
            query.append(.init(name: "unit", value: String(unit)))
        }

        return try await api.request(
            "GET",
            "admin/example-sentences/multi-sentence",
            query: query,
            as: [ExampleSentence].self
        )
    }

    // example_sentence를 생성합니다.
    @discardableResult
    func createExampleSentence(payload: ExampleSentenceCreate) async throws -> ExampleSentence {
        try await api.request(
            "POST",
            "admin/example-sentences",
            jsonBody: payload.toDict(),
            as: ExampleSentence.self
        )
    }

    // example_sentence 단건을 조회합니다.
    func exampleSentence(id: Int) async throws -> ExampleSentence {
        try await api.request(
            "GET",
            "admin/example-sentences/\(id)",
            as: ExampleSentence.self
        )
    }

    // example_sentence를 수정합니다.
    @discardableResult
    func updateExampleSentence(
        id: Int,
        payload: ExampleSentenceUpdate
    ) async throws -> ExampleSentence {
        try await api.request(
            "PUT",
            "admin/example-sentences/\(id)",
            jsonBody: payload.toDict(),
            as: ExampleSentence.self
        )
    }

    // example_sentence 번역을 전체 치환합니다.
    @discardableResult
    func replaceTranslations(
        id: Int,
        payload: ExampleSentenceTranslationsReplace
    ) async throws -> ExampleSentence {
        try await api.request(
            "PUT",
            "admin/example-sentences/\(id)/translations",
            jsonBody: payload.toDict(),
            as: ExampleSentence.self
        )
    }

    // example_sentence를 삭제합니다.
    func deleteExampleSentence(id: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/example-sentences/\(id)",
            as: Empty.self
        )
    }
}
