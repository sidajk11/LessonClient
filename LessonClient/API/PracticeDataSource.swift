//
//  PracticeDataSource.swift
//  LessonClient
//
//  Created by ymj on 10/01/25
//

import Foundation

final class PracticeDataSource {
    static let shared = PracticeDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Public API

    /// 목록 조회 (예문별 필터 가능)
    func list(exampleId: Int? = nil, limit: Int = 50) async throws -> [Practice] {
        var query: [URLQueryItem] = [.init(name: "limit", value: "\(min(max(limit, 1), 200))")]
        if let exampleId { query.append(.init(name: "example_id", value: "\(exampleId)")) }
        return try await api.request("GET", "admin/practices", query: query, as: [Practice].self)
    }

    /// 단건 조회
    func get(id: Int) async throws -> Practice {
        try await api.request("GET", "admin/practices/\(id)", as: Practice.self)
    }

    /// 생성
    @discardableResult
    func create(practice: PracticeUpdate) async throws -> Practice {
        return try await api.request("POST", "admin/practices", jsonBody: practice.toDict(), as: Practice.self)
    }

    /// 수정 (전달한 항목만 갱신, 옵션/번역은 전달 시 전체 치환)
    @discardableResult
    func update(id: Int, practice: PracticeUpdate) async throws -> Practice {
        return try await api.request("PUT", "admin/practices/\(id)", jsonBody: practice.toDict(), as: Practice.self)
    }

    /// 삭제
    func delete(id: Int) async throws {
        _ = try await api.request("DELETE", "admin/practices/\(id)", as: Empty.self)
    }
    
    /// 연습문제 검색 (GET /practices/search)
    /// - Parameters:
    ///   - q: 부분검색어 (연습문제/예문/번역/선택지)
    ///   - level: Lesson.level 정확 일치
    ///   - unit: Lesson.unit 정확 일치
    ///   - limit: 1...200
    /// - Returns: Practice 배열 (서버의 PracticeOut과 동일 구조 가정)
    func search(
        q: String = "",
        level: Int? = nil,
        unit: Int? = nil,
        limit: Int = 50
    ) async throws -> [Practice] {
        let trimmedQ = q.trimmingCharacters(in: .whitespacesAndNewlines)
        let clampedLimit = min(max(limit, 1), 200)

        var query: [URLQueryItem] = [
            .init(name: "q", value: trimmedQ),
            .init(name: "limit", value: String(clampedLimit))
        ]
        if let level { query.append(.init(name: "level", value: String(level))) }
        if let unit  { query.append(.init(name: "unit",  value: String(unit))) }

        return try await api.request(
            "GET",
            "admin/practices/search",
            query: query,
            as: [Practice].self
        )
    }

}


