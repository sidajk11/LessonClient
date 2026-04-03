//
//  UserLessonTargetStateModel.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

struct UserVocabularyStateRead: Codable, Identifiable {
    let id: Int
    let userId: Int
    let vocabularyId: Int
    let attempts: Int
    let correctAttempts: Int
    let wrongStreak: Int
    let lastAttemptAt: Date?
    let lastCorrectAt: Date?
    let nextReviewAt: Date?
    let updatedAt: Date?

    var lessonTargetId: Int { vocabularyId }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case vocabularyId = "vocabulary_id"
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
        vocabularyId = try c.decode(Int.self, forKey: .vocabularyId)
        attempts = try c.decode(Int.self, forKey: .attempts)
        correctAttempts = try c.decode(Int.self, forKey: .correctAttempts)
        wrongStreak = try c.decode(Int.self, forKey: .wrongStreak)
        lastAttemptAt = try c.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        lastCorrectAt = try c.decodeIfPresent(Date.self, forKey: .lastCorrectAt)
        nextReviewAt = try c.decodeIfPresent(Date.self, forKey: .nextReviewAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct UserVocabularyStateCreate: Codable {
    let userId: Int
    let vocabularyId: Int
    let attempts: Int
    let correctAttempts: Int
    let wrongStreak: Int
    let lastAttemptAt: Date?
    let lastCorrectAt: Date?
    let nextReviewAt: Date?

    init(
        userId: Int,
        vocabularyId: Int,
        attempts: Int = 0,
        correctAttempts: Int = 0,
        wrongStreak: Int = 0,
        lastAttemptAt: Date? = nil,
        lastCorrectAt: Date? = nil,
        nextReviewAt: Date? = nil
    ) {
        self.userId = userId
        self.vocabularyId = vocabularyId
        self.attempts = attempts
        self.correctAttempts = correctAttempts
        self.wrongStreak = wrongStreak
        self.lastAttemptAt = lastAttemptAt
        self.lastCorrectAt = lastCorrectAt
        self.nextReviewAt = nextReviewAt
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case vocabularyId = "vocabulary_id"
        case attempts
        case correctAttempts = "correct_attempts"
        case wrongStreak = "wrong_streak"
        case lastAttemptAt = "last_attempt_at"
        case lastCorrectAt = "last_correct_at"
        case nextReviewAt = "next_review_at"
    }
}

struct UserVocabularyStateUpdate: Codable {
    let userId: Int?
    let vocabularyId: Int?
    let attempts: Int?
    let correctAttempts: Int?
    let wrongStreak: Int?
    let lastAttemptAt: Date?
    let lastCorrectAt: Date?
    let nextReviewAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case vocabularyId = "vocabulary_id"
        case attempts
        case correctAttempts = "correct_attempts"
        case wrongStreak = "wrong_streak"
        case lastAttemptAt = "last_attempt_at"
        case lastCorrectAt = "last_correct_at"
        case nextReviewAt = "next_review_at"
    }
}

typealias UserLessonTargetStateRead = UserVocabularyStateRead
typealias UserLessonTargetStateCreate = UserVocabularyStateCreate
typealias UserLessonTargetStateUpdate = UserVocabularyStateUpdate
