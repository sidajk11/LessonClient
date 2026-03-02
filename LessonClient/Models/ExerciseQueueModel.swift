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

        let batchCompletedAtRaw = try c.decodeIfPresent(String.self, forKey: .batchCompletedAt)
        let createdAtRaw = try c.decodeIfPresent(String.self, forKey: .createdAt)
        let consumedAtRaw = try c.decodeIfPresent(String.self, forKey: .consumedAt)

        batchCompletedAt = ExerciseQueueDateParser.parse(batchCompletedAtRaw)
        createdAt = ExerciseQueueDateParser.parse(createdAtRaw)
        consumedAt = ExerciseQueueDateParser.parse(consumedAtRaw)
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

private enum ExerciseQueueDateParser {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return iso8601WithFractional.date(from: raw) ?? iso8601.date(from: raw)
    }

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
