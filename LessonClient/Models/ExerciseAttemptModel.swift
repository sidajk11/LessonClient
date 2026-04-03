//
//  ExerciseAttemptModel.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

struct ExerciseAttemptRead: Codable, Identifiable {
    let id: UUID
    let userId: Int
    let exerciseId: Int
    let isCorrect: Bool
    let score: Int?
    let durationMs: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case isCorrect = "is_correct"
        case score
        case durationMs = "duration_ms"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        exerciseId = try c.decode(Int.self, forKey: .exerciseId)
        isCorrect = try c.decode(Bool.self, forKey: .isCorrect)
        score = try c.decodeIfPresent(Int.self, forKey: .score)
        durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct ExerciseAttemptCreate: Codable {
    let userId: Int
    let exerciseId: Int
    let isCorrect: Bool
    let score: Int?
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case isCorrect = "is_correct"
        case score
        case durationMs = "duration_ms"
    }
}

struct ExerciseAttemptUpdate: Codable {
    let userId: Int?
    let exerciseId: Int?
    let isCorrect: Bool?
    let score: Int?
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exerciseId = "exercise_id"
        case isCorrect = "is_correct"
        case score
        case durationMs = "duration_ms"
    }
}
