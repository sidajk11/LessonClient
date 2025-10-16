//
//  LessonDataSource.swift
//  LessonClient
//
//  Updated for Lesson { unit:Int, level:Int } (no Level/Unit tables)
//

import Foundation

final class LessonDataSource {
    static let shared = LessonDataSource()
    private let api = APIClient.shared
    private init() {}

    /// POST /lessons/{lesson_id}/words
    private struct AttachWordBody: Codable {
        let wordId: Int
        enum CodingKeys: String, CodingKey { case wordId = "word_id" }
    }

    // MARK: - Lessons

    /// 레슨 생성
    @discardableResult
    func createLesson(
        unit: Int,
        level: Int,
        grammar: String? = nil,
        topic: [LocalizedText]? = nil,
        wordIds: [Int]? = nil
    ) async throws -> Lesson {
        let body = LessonUpdate(
            unit: unit,
            level: level,
            grammar: grammar,
            topic: topic,
            wordIds: wordIds
        )
        return try await api.request("POST", "/lessons", jsonBody: body, as: Lesson.self)
    }

    /// 레슨 목록
    func lessons(
        level: Int? = nil,
        unit: Int? = nil
    ) async throws -> [Lesson] {
        var query: [URLQueryItem] = []
        if let level { query.append(.init(name: "level", value: "\(level)")) }
        if let unit { query.append(.init(name: "unit", value: "\(unit)")) }
        return try await api.request("GET", "/lessons", query: query.isEmpty ? nil : query, as: [Lesson].self)
    }

    func lesson(id: Int) async throws -> Lesson {
        try await api.request("GET", "/lessons/\(id)", as: Lesson.self)
    }

    /// 레슨 수정 (전달한 필드만 갱신, translation/wordIds는 전체 치환 정책)
    @discardableResult
    func updateLesson(
        id: Int,
        unit: Int? = nil,
        level: Int? = nil,
        grammar: String? = nil,
        topic: [LocalizedText]? = nil,
        wordIds: [Int]? = nil
    ) async throws -> Lesson {
        let body = LessonUpdate(
            unit: unit,
            level: level,
            grammar: grammar,
            topic: topic,
            wordIds: wordIds
        )
        return try await api.request("PUT", "/lessons/\(id)", jsonBody: body, as: Lesson.self)
    }

    func deleteLesson(id: Int) async throws {
        _ = try await api.request("DELETE", "/lessons/\(id)", as: Empty.self)
    }

    // MARK: - Word attach/detach (1:N)

    /// 단어 연결/이동
    @discardableResult
    func attachWord(lessonId: Int, wordId: Int) async throws -> Lesson {
        let body = AttachWordBody(wordId: wordId)
        return try await api.request("POST", "/lessons/\(lessonId)/words", jsonBody: body, as: Lesson.self)
    }

    /// 단어 분리(detach) → 서버가 Lesson 반환
    @discardableResult
    func detachWord(lessonId: Int, wordId: Int) async throws -> Lesson {
        try await api.request("DELETE", "/lessons/\(lessonId)/words/\(wordId)", as: Lesson.self)
    }
}
