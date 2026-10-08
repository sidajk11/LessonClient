//
//  LessonDataSource.swift
//  LessonClient
//
//  Updated for Lesson { unit:Int, level:Int } and vocabulary-based lesson targets.
//

import Foundation

final class LessonDataSource {
    static let shared = LessonDataSource()
    private let api = APIClient.shared

    private init() {}
}

extension LessonDataSource {
    /// POST /lessons/{lesson_id}/vocabularies
    private struct AttachVocabularyBody: Codable {
        let vocabularyId: Int
        enum CodingKeys: String, CodingKey { case vocabularyId = "vocabulary_id" }
    }

    // MARK: - Lessons

    /// 레슨 생성
    @discardableResult
    func createLesson(
        unit: Int,
        level: Int,
        trackCode: String = "en-US",
        grammar: String? = nil,
        translations: [LessonTranslation]? = nil,
        lessonTargets: [LessonTargetUpsertSchema]? = nil,
        vocabularyIds: [Int]? = nil,
        wordIds: [Int]? = nil // backward-compatible alias
    ) async throws -> Lesson {
        let body = LessonUpdate(
            unit: unit,
            level: level,
            trackCode: trackCode,
            grammar: grammar,
            vocabularyIds: vocabularyIds ?? wordIds,
            lessonTargets: lessonTargets,
            translations: translations
        )
        return try await api.request("POST", "admin/lessons", jsonBody: body.toDict(), as: Lesson.self)
    }

    /// 레슨 목록
    func lessons(
        level: Int? = nil,
        unit: Int? = nil,
        limit: Int = 10
    ) async throws -> [Lesson] {
        var query: [URLQueryItem] = []
        if let level { query.append(.init(name: "level", value: "\(level)")) }
        if let unit { query.append(.init(name: "unit", value: "\(unit)")) }
        query.append(URLQueryItem(name: "limit", value: String(limit)))
        return try await api.request("GET", "admin/lessons", query: query.isEmpty ? nil : query, as: [Lesson].self)
    }

    func lesson(id: Int) async throws -> Lesson {
        try await api.request("GET", "admin/lessons/\(id)", as: Lesson.self)
    }

    func nextUnit(limit: Int = 1) async throws -> Int {
        let items = try await lessons(limit: limit)
        let maxUnit = items.map(\.unit).max() ?? 0
        return maxUnit + 1
    }

    /// 레슨 수정 (전달한 필드만 갱신, translation/vocabularyIds는 전체 치환 정책)
    @discardableResult
    func updateLesson(
        id: Int,
        unit: Int? = nil,
        level: Int? = nil,
        trackCode: String? = nil,
        grammar: String? = nil,
        vocabularyIds: [Int]? = nil,
        wordIds: [Int]? = nil, // backward-compatible alias
        lessonTargets: [LessonTargetUpsertSchema]? = nil,
        translations: [LessonTranslation]? = nil
    ) async throws -> Lesson {
        let body = LessonUpdate(
            unit: unit,
            level: level,
            trackCode: trackCode,
            grammar: grammar,
            vocabularyIds: vocabularyIds ?? wordIds,
            lessonTargets: lessonTargets,
            translations: translations
        )
        return try await api.request("PUT", "admin/lessons/\(id)", jsonBody: body.toDict(), as: Lesson.self)
    }

    func deleteLesson(id: Int) async throws {
        _ = try await api.request("DELETE", "admin/lessons/\(id)", as: Empty.self)
    }

    // MARK: - Vocabulary attach/detach (1:N)

    /// 단어 연결/이동
    @discardableResult
    func attachVocabulary(lessonId: Int, vocabularyId: Int) async throws -> Lesson {
        let body = AttachVocabularyBody(vocabularyId: vocabularyId)
        return try await api.request(
            "POST",
            "admin/lessons/\(lessonId)/vocabularies",
            jsonBody: body.toDict(),
            as: Lesson.self
        )
    }

    /// 단어 분리(detach) → 서버가 Lesson 반환
    @discardableResult
    func detachVocabulary(lessonId: Int, vocabularyId: Int) async throws -> Lesson {
        try await api.request("DELETE", "admin/lessons/\(lessonId)/vocabularies/\(vocabularyId)", as: Lesson.self)
    }

    // Backward-compatible aliases.
    @discardableResult
    func attachVocabulary(lessonId: Int, wordId: Int) async throws -> Lesson {
        try await attachVocabulary(lessonId: lessonId, vocabularyId: wordId)
    }

    @discardableResult
    func detachVocabulary(lessonId: Int, wordId: Int) async throws -> Lesson {
        try await detachVocabulary(lessonId: lessonId, vocabularyId: wordId)
    }
}
