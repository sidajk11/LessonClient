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
    ///   - wordId: 상위 단어 ID
    ///   - translation: 예문 번역(전체 치환 정책). en/ko 등 언어별 텍스트
    /// - Returns: 생성된 Example
    @discardableResult
    func createExample(
        wordId: Int,
        text: String,
        translation: [LocalizedText]? = nil
    ) async throws -> Example {
        let body = ExampleUpdate(wordId: wordId, text: text, translation: translation)
        return try await api.request("POST", "/examples", jsonBody: body, as: Example.self)
    }

    /// 예문 단건 조회
    func example(id: Int) async throws -> Example {
        try await api.request("GET", "/examples/\(id)", as: Example.self)
    }

    /// 예문 수정
    /// - Parameters:
    ///   - id: 예문 ID
    ///   - wordId: 변경할 단어 ID(옵션)
    ///   - translation: 전달 시 해당 예문의 번역을 전체 치환
    @discardableResult
    func updateExample(
        id: Int,
        wordId: Int? = nil,
        translation: [LocalizedText]? = nil
    ) async throws -> Example {
        let body = ExampleUpdate(wordId: wordId, translation: translation)
        return try await api.request("PUT", "/examples/\(id)", jsonBody: body, as: Example.self)
    }

    /// 예문 삭제
    func deleteExample(id: Int) async throws {
        _ = try await api.request("DELETE", "/examples/\(id)", as: Empty.self)
    }

    // MARK: - Search

    /// 예문 검색
    /// - Parameters:
    ///   - q: 부분검색(단어 텍스트 / en / 요청 lang 번역)
    ///   - levelCode: Level.code (예: "1", "A1")
    ///   - unitNumber: Unit.number
    ///   - lang: 요청 번역 언어코드 (기본 "ko")
    ///   - limit: 최대 개수(1...200)
    func search(
        q: String = "",
        levelCode: String? = nil,
        unitNumber: Int? = nil,
        lang: String = "ko",
        limit: Int = 30
    ) async throws -> [Example] {
        var query: [URLQueryItem] = [
            .init(name: "q", value: q),
            .init(name: "lang", value: lang),
            .init(name: "limit", value: "\(min(max(limit, 1), 200))")
        ]
        if let levelCode { query.append(.init(name: "level_code", value: levelCode)) }
        if let unitNumber { query.append(.init(name: "unit_number", value: "\(unitNumber)")) }

        return try await api.request(
            "GET",
            "/examples/search",
            query: query,
            as: [Example].self
        )
    }

    func examples(wordId: Int) async throws -> [Example] {
        try await api.request("GET", "/examples/by-word/\(wordId)", as: [Example].self)
    }
}
