//
//  ExerciseQueueDataSource.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

final class ExerciseQueueDataSource {
    static let shared = ExerciseQueueDataSource()
    private let api = APIClient.shared
    private init() {}

    func listExerciseQueues(
        userId: Int? = nil,
        batchId: Int? = nil,
        exerciseId: Int? = nil,
        consumed: Bool? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ExerciseQueueRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        if let userId { query.append(.init(name: "user_id", value: String(userId))) }
        if let batchId { query.append(.init(name: "batch_id", value: String(batchId))) }
        if let exerciseId { query.append(.init(name: "exercise_id", value: String(exerciseId))) }
        if let consumed { query.append(.init(name: "consumed", value: String(consumed))) }

        return try await api.request(
            "GET",
            "admin/exercise-queues",
            query: query,
            as: [ExerciseQueueRead].self
        )
    }

    @discardableResult
    func createExerciseQueue(payload: ExerciseQueueCreate) async throws -> ExerciseQueueRead {
        return try await api.request(
            "POST",
            "admin/exercise-queues",
            jsonBody: payload.toDict(),
            as: ExerciseQueueRead.self
        )
    }

    func exerciseQueue(id queueId: Int) async throws -> ExerciseQueueRead {
        try await api.request(
            "GET",
            "admin/exercise-queues/\(queueId)",
            as: ExerciseQueueRead.self
        )
    }

    @discardableResult
    func updateExerciseQueue(id queueId: Int, payload: ExerciseQueueUpdate) async throws -> ExerciseQueueRead {
        return try await api.request(
            "PUT",
            "admin/exercise-queues/\(queueId)",
            jsonBody: payload.toDict(),
            as: ExerciseQueueRead.self
        )
    }

    func deleteExerciseQueue(id queueId: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/exercise-queues/\(queueId)",
            as: Empty.self
        )
    }
}
