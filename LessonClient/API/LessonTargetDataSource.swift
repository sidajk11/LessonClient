//
//  LessonTargetDataSource.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import Foundation

final class LessonTargetDataSource {
    static let shared = LessonTargetDataSource()
    private let api = APIClient.shared
    private init() {}

    func listLessonTargets(
        lessonId: Int? = nil,
        targetType: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [LessonTargetRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let lessonId { query.append(.init(name: "lesson_id", value: String(lessonId))) }
        if let targetType, !targetType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(.init(name: "target_type", value: targetType.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return try await api.request(
            "GET",
            "admin/lesson-targets",
            query: query,
            as: [LessonTargetRead].self
        )
    }

    @discardableResult
    func createLessonTarget(
        lessonId: Int,
        targetType: String,
        vocabularyId: Int? = nil,
        displayText: String,
        sortIndex: Int
    ) async throws -> LessonTargetRead {
        let body = LessonTargetCreate(
            lessonId: lessonId,
            targetType: targetType,
            vocabularyId: vocabularyId,
            displayText: displayText,
            sortIndex: sortIndex
        )
        return try await api.request(
            "POST",
            "admin/lesson-targets",
            jsonBody: body.toDict(),
            as: LessonTargetRead.self
        )
    }

    func lessonTarget(id: Int) async throws -> LessonTargetRead {
        try await api.request("GET", "admin/lesson-targets/\(id)", as: LessonTargetRead.self)
    }

    @discardableResult
    func updateLessonTarget(
        id: Int,
        lessonId: Int? = nil,
        targetType: String? = nil,
        vocabularyId: Int? = nil,
        displayText: String? = nil,
        sortIndex: Int? = nil
    ) async throws -> LessonTargetRead {
        let body = LessonTargetUpdate(
            lessonId: lessonId,
            targetType: targetType,
            vocabularyId: vocabularyId,
            displayText: displayText,
            sortIndex: sortIndex
        )
        return try await api.request(
            "PUT",
            "admin/lesson-targets/\(id)",
            jsonBody: body.toDict(),
            as: LessonTargetRead.self
        )
    }

    // Backward-compatible signatures.
    @discardableResult
    func createLessonTarget(
        lessonId: Int,
        targetType: String,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        displayText: String,
        sortIndex: Int
    ) async throws -> LessonTargetRead {
        try await createLessonTarget(
            lessonId: lessonId,
            targetType: targetType,
            vocabularyId: wordId,
            displayText: displayText,
            sortIndex: sortIndex
        )
    }

    @discardableResult
    func updateLessonTarget(
        id: Int,
        lessonId: Int? = nil,
        targetType: String? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        displayText: String? = nil,
        sortIndex: Int? = nil
    ) async throws -> LessonTargetRead {
        try await updateLessonTarget(
            id: id,
            lessonId: lessonId,
            targetType: targetType,
            vocabularyId: wordId,
            displayText: displayText,
            sortIndex: sortIndex
        )
    }

    func deleteLessonTarget(id: Int) async throws {
        _ = try await api.request("DELETE", "admin/lesson-targets/\(id)", as: Empty.self)
    }
}
