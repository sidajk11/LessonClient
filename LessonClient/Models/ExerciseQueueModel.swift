//
//  ExerciseQueueModel.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

struct ExerciseQueueRead: Codable, Identifiable {
    let id: Int
    let userId: Int
    let exerciseId: Int
    let batchId: Int
    let position: Int
    let batchUnit: Int?
    let batchCompletedAt: Date?
    let createdAt: Date?
    let consumedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case batchId = "batch_id"
        case position
        case batchUnit = "batch_unit"
        case batchCompletedAt = "batch_completed_at"
        case createdAt = "created_at"
        case consumedAt = "consumed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        exerciseId = try c.decode(Int.self, forKey: .exerciseId)
        batchId = try c.decode(Int.self, forKey: .batchId)
        position = try c.decode(Int.self, forKey: .position)
        batchUnit = try c.decodeIfPresent(Int.self, forKey: .batchUnit)
        batchCompletedAt = try c.decodeIfPresent(Date.self, forKey: .batchCompletedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        consumedAt = try c.decodeIfPresent(Date.self, forKey: .consumedAt)
    }
}

struct ExerciseQueueCreate: Codable {
    let userId: Int
    let exerciseId: Int
    let batchId: Int
    let position: Int
    let batchUnit: Int?
    let batchCompletedAt: Date?
    let consumedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case batchId = "batch_id"
        case position
        case batchUnit = "batch_unit"
        case batchCompletedAt = "batch_completed_at"
        case consumedAt = "consumed_at"
    }
}

struct ExerciseQueueUpdate: Codable {
    let userId: Int?
    let exerciseId: Int?
    let batchId: Int?
    let position: Int?
    let batchUnit: Int?
    let batchCompletedAt: Date?
    let consumedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case batchId = "batch_id"
        case position
        case batchUnit = "batch_unit"
        case batchCompletedAt = "batch_completed_at"
        case consumedAt = "consumed_at"
    }
}
