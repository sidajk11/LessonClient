//
//  UserLessonTargetStateDataSource.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

final class UserLessonTargetStateDataSource {
    static let shared = UserLessonTargetStateDataSource()
    private let api = APIClient.shared
    private init() {}

    func listUserLessonTargetStates(
        userId: Int? = nil,
        lessonTargetId: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [UserLessonTargetStateRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        if let userId { query.append(.init(name: "user_id", value: String(userId))) }
        if let lessonTargetId { query.append(.init(name: "lesson_target_id", value: String(lessonTargetId))) }

        return try await api.request(
            "GET",
            "admin/user-lesson-target-states",
            query: query,
            as: [UserLessonTargetStateRead].self
        )
    }

    @discardableResult
    func createUserLessonTargetState(payload: UserLessonTargetStateCreate) async throws -> UserLessonTargetStateRead {
        return try await api.request(
            "POST",
            "admin/user-lesson-target-states",
            jsonBody: payload.toDict(),
            as: UserLessonTargetStateRead.self
        )
    }

    func userLessonTargetState(id stateId: Int) async throws -> UserLessonTargetStateRead {
        try await api.request(
            "GET",
            "admin/user-lesson-target-states/\(stateId)",
            as: UserLessonTargetStateRead.self
        )
    }

    @discardableResult
    func updateUserLessonTargetState(
        id stateId: Int,
        payload: UserLessonTargetStateUpdate
    ) async throws -> UserLessonTargetStateRead {
        return try await api.request(
            "PUT",
            "admin/user-lesson-target-states/\(stateId)",
            jsonBody: payload.toDict(),
            as: UserLessonTargetStateRead.self
        )
    }

    func deleteUserLessonTargetState(id stateId: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/user-lesson-target-states/\(stateId)",
            as: Empty.self
        )
    }
}
