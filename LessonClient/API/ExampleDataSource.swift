//
//  ExampleDataSource.swift
//  LessonClient
//
//  Created by ymj on 10/1/25.
//

import Foundation

final class ExampleDataSource {
    static let shared = ExampleDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Public API

    /// 예문 생성
    /// - Parameters:
    ///   - sentence: 예문 원문
    ///   - vocabularyId: 연결할 단어 ID
    ///   - lessonTargetId: 연결할 레슨 타겟 ID
    ///   - phraseId: 연결할 구문 ID
    ///   - translations: 예문 번역(전체 치환 정책). en/ko 등 언어별 텍스트
    /// - Returns: 생성된 Example
    @discardableResult
    func createExample(
        sentence: String,
        vocabularyId: Int?,
        lessonTargetId: Int? = nil,
        phraseId: Int? = nil,
        translations: [ExampleTranslation]? = nil
    ) async throws -> Example {
        let body = ExampleCreate(
            sentence: sentence,
            vocabularyId: vocabularyId,
            lessonTargetId: lessonTargetId,
            phraseId: phraseId,
            translations: translations
        )
        return try await api.request("POST", "admin/examples", jsonBody: body.toDict(), as: Example.self)
    }

    /// 예문 단건 조회
    func example(id: Int) async throws -> Example {
        try await api.request("GET", "admin/examples/\(id)", as: Example.self)
    }

    /// 예문 수정
    /// - Parameters:
    ///   - id: 예문 ID
    ///   - vocabularyId: 변경할 단어 ID(옵션)
    ///   - lessonTargetId: 변경할 레슨 타겟 ID(옵션)
    ///   - phraseId: 변경할 구문 ID(옵션)
    ///   - translations: 전달 시 해당 예문의 번역을 전체 치환
    @discardableResult
    func updateExample(
        id: Int,
        sentence: String?,
        vocabularyId: Int? = nil,
        lessonTargetId: Int? = nil,
        phraseId: Int? = nil,
        translations: [ExampleTranslation]? = nil
    ) async throws -> Example {
        let body = ExampleUpdate(
            sentence: sentence,
            vocabularyId: vocabularyId,
            lessonTargetId: lessonTargetId,
            phraseId: phraseId,
            translations: translations
        )
        return try await api.request("PUT", "admin/examples/\(id)", jsonBody: body.toDict(), as: Example.self)
    }

    /// 예문 삭제
    func deleteExample(id: Int) async throws {
        _ = try await api.request("DELETE", "admin/examples/\(id)", as: Empty.self)
    }

    // MARK: - Search

    /// 예문 검색
    /// - Parameters:
    ///   - q: 부분검색(문장/번역 등)
    ///   - level: lesson.level
    ///   - unit: lesson.unit
    ///   - limit: 최대 개수(1...200)
    func search(
        q: String = "",
        level: Int? = nil,
        unit: Int? = nil,
        limit: Int = 30
    ) async throws -> [Example] {
        let trimmedQ = q.trimmingCharacters(in: .whitespacesAndNewlines)
        var query: [URLQueryItem] = [
            .init(name: "q", value: trimmedQ),
            .init(name: "limit", value: "\(min(max(limit, 1), 200))")
        ]
        if let level { query.append(.init(name: "level", value: "\(level)")) }
        if let unit { query.append(.init(name: "unit", value: "\(unit)")) }

        return try await api.request(
            "GET",
            "admin/examples/search",
            query: query,
            as: [Example].self
        )
    }

    func examples(wordId: Int, limit: Int = 100) async throws -> [Example] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200)))
        ]
        return try await api.request(
            "GET",
            "admin/examples/by-vocabulary/\(wordId)",
            query: query,
            as: [Example].self
        )
    }

    /// sense 기준 예문 목록 조회
    /// - Parameters:
    ///   - senseId: WordSense ID
    ///   - limit: 최대 개수(1...200)
    func examples(senseId: Int, limit: Int = 100) async throws -> [Example] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200)))
        ]
        return try await api.request(
            "GET",
            "admin/examples/by-sense/\(senseId)",
            query: query,
            as: [Example].self
        )
    }

    /// phrase 기준 예문 목록 조회
    /// - Parameters:
    ///   - phraseId: Phrase ID
    ///   - limit: 최대 개수(1...200)
    func examples(phraseId: Int, limit: Int = 100) async throws -> [Example] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200)))
        ]
        return try await api.request(
            "GET",
            "admin/examples/by-phrase/\(phraseId)",
            query: query,
            as: [Example].self
        )
    }
}
