//
//  UserLessonTargetStateModel.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

struct UserLessonTargetStateRead: Codable, Identifiable {
    let id: Int
    let userId: Int
    let lessonTargetId: Int
    let attempts: Int
    let correctAttempts: Int
    let wrongStreak: Int
    let lastAttemptAt: Date?
    let lastCorrectAt: Date?
    let nextReviewAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case lessonTargetId = "lesson_target_id"
        case attempts
        case correctAttempts = "correct_attempts"
        case wrongStreak = "wrong_streak"
        case lastAttemptAt = "last_attempt_at"
        case lastCorrectAt = "last_correct_at"
        case nextReviewAt = "next_review_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        lessonTargetId = try c.decode(Int.self, forKey: .lessonTargetId)
        attempts = try c.decode(Int.self, forKey: .attempts)
        correctAttempts = try c.decode(Int.self, forKey: .correctAttempts)
        wrongStreak = try c.decode(Int.self, forKey: .wrongStreak)

        let lastAttemptAtRaw = try c.decodeIfPresent(String.self, forKey: .lastAttemptAt)
        let lastCorrectAtRaw = try c.decodeIfPresent(String.self, forKey: .lastCorrectAt)
        let nextReviewAtRaw = try c.decodeIfPresent(String.self, forKey: .nextReviewAt)
        let updatedAtRaw = try c.decodeIfPresent(String.self, forKey: .updatedAt)

        lastAttemptAt = UserLessonTargetStateDateParser.parse(lastAttemptAtRaw)
        lastCorrectAt = UserLessonTargetStateDateParser.parse(lastCorrectAtRaw)
        nextReviewAt = UserLessonTargetStateDateParser.parse(nextReviewAtRaw)
        updatedAt = UserLessonTargetStateDateParser.parse(updatedAtRaw)
    }
}

struct UserLessonTargetStateCreate: Codable {
    let userId: Int
    let lessonTargetId: Int
    let attempts: Int
    let correctAttempts: Int
    let wrongStreak: Int
    let lastAttemptAt: Date?
    let lastCorrectAt: Date?
    let nextReviewAt: Date?

    init(
        userId: Int,
        lessonTargetId: Int,
        attempts: Int = 0,
        correctAttempts: Int = 0,
        wrongStreak: Int = 0,
        lastAttemptAt: Date? = nil,
        lastCorrectAt: Date? = nil,
        nextReviewAt: Date? = nil
    ) {
        self.userId = userId
        self.lessonTargetId = lessonTargetId
        self.attempts = attempts
        self.correctAttempts = correctAttempts
        self.wrongStreak = wrongStreak
        self.lastAttemptAt = lastAttemptAt
        self.lastCorrectAt = lastCorrectAt
        self.nextReviewAt = nextReviewAt
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lessonTargetId = "lesson_target_id"
        case attempts
        case correctAttempts = "correct_attempts"
        case wrongStreak = "wrong_streak"
        case lastAttemptAt = "last_attempt_at"
        case lastCorrectAt = "last_correct_at"
        case nextReviewAt = "next_review_at"
    }
}

struct UserLessonTargetStateUpdate: Codable {
    let userId: Int?
    let lessonTargetId: Int?
    let attempts: Int?
    let correctAttempts: Int?
    let wrongStreak: Int?
    let lastAttemptAt: Date?
    let lastCorrectAt: Date?
    let nextReviewAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lessonTargetId = "lesson_target_id"
        case attempts
        case correctAttempts = "correct_attempts"
        case wrongStreak = "wrong_streak"
        case lastAttemptAt = "last_attempt_at"
        case lastCorrectAt = "last_correct_at"
        case nextReviewAt = "next_review_at"
    }
}

private enum UserLessonTargetStateDateParser {
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
