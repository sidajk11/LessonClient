//
//  ExerciseAttemptDataSource.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

final class ExerciseAttemptDataSource {
    static let shared = ExerciseAttemptDataSource()
    private let api = APIClient.shared
    private init() {}

    func listExerciseAttempts(
        userId: Int? = nil,
        exerciseId: Int? = nil,
        isCorrect: Bool? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ExerciseAttemptRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        if let userId { query.append(.init(name: "user_id", value: String(userId))) }
        if let exerciseId { query.append(.init(name: "exercise_id", value: String(exerciseId))) }
        if let isCorrect { query.append(.init(name: "is_correct", value: String(isCorrect))) }

        return try await api.request(
            "GET",
            "admin/exercise-attempts",
            query: query,
            as: [ExerciseAttemptRead].self
        )
    }

    @discardableResult
    func createExerciseAttempt(payload: ExerciseAttemptCreate) async throws -> ExerciseAttemptRead {
        return try await api.request(
            "POST",
            "admin/exercise-attempts",
            jsonBody: payload.toDict(),
            as: ExerciseAttemptRead.self
        )
    }

    func exerciseAttempt(id attemptId: UUID) async throws -> ExerciseAttemptRead {
        try await api.request(
            "GET",
            "admin/exercise-attempts/\(attemptId.uuidString)",
            as: ExerciseAttemptRead.self
        )
    }

    @discardableResult
    func updateExerciseAttempt(id attemptId: UUID, payload: ExerciseAttemptUpdate) async throws -> ExerciseAttemptRead {
        return try await api.request(
            "PUT",
            "admin/exercise-attempts/\(attemptId.uuidString)",
            jsonBody: payload.toDict(),
            as: ExerciseAttemptRead.self
        )
    }

    func deleteExerciseAttempt(id attemptId: UUID) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/exercise-attempts/\(attemptId.uuidString)",
            as: Empty.self
        )
    }
}
