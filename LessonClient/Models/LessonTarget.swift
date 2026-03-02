//
//  LessonTarget.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import Foundation

struct LessonTargetRead: Codable, Identifiable {
    let id: Int
    let lessonId: Int
    let targetType: String
    let vocabularyId: Int?
    let displayText: String
    let sortIndex: Int
    let createdAt: Date?
    let lastReviewedAt: Date?
    let nextReviewAt: Date?

    // Backward-compatible aliases for older UI references.
    var wordId: Int? { vocabularyId }
    var formId: Int? { nil }
    var senseId: Int? { nil }
    var phraseId: Int? { nil }

    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case targetType = "target_type"
        case vocabularyId = "vocabulary_id"
        case displayText = "display_text"
        case sortIndex = "sort_index"
        case createdAt = "created_at"
        case lastReviewedAt = "last_reviewed_at"
        case nextReviewAt = "next_review_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        lessonId = try c.decode(Int.self, forKey: .lessonId)
        targetType = try c.decode(String.self, forKey: .targetType)
        vocabularyId = try c.decodeIfPresent(Int.self, forKey: .vocabularyId)
        displayText = try c.decode(String.self, forKey: .displayText)
        sortIndex = try c.decode(Int.self, forKey: .sortIndex)

        let createdAtRaw = try c.decodeIfPresent(String.self, forKey: .createdAt)
        let lastReviewedAtRaw = try c.decodeIfPresent(String.self, forKey: .lastReviewedAt)
        let nextReviewAtRaw = try c.decodeIfPresent(String.self, forKey: .nextReviewAt)
        createdAt = LessonTargetDateParser.parse(createdAtRaw)
        lastReviewedAt = LessonTargetDateParser.parse(lastReviewedAtRaw)
        nextReviewAt = LessonTargetDateParser.parse(nextReviewAtRaw)
    }
}

struct LessonTargetCreate: Codable {
    let lessonId: Int
    let targetType: String
    let vocabularyId: Int?
    let displayText: String
    let sortIndex: Int

    init(
        lessonId: Int,
        targetType: String,
        vocabularyId: Int? = nil,
        displayText: String,
        sortIndex: Int
    ) {
        self.lessonId = lessonId
        self.targetType = targetType
        self.vocabularyId = vocabularyId
        self.displayText = displayText
        self.sortIndex = sortIndex
    }

    // Backward-compatible initializer.
    init(
        lessonId: Int,
        targetType: String,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        displayText: String,
        sortIndex: Int
    ) {
        self.init(
            lessonId: lessonId,
            targetType: targetType,
            vocabularyId: wordId,
            displayText: displayText,
            sortIndex: sortIndex
        )
    }

    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case targetType = "target_type"
        case vocabularyId = "vocabulary_id"
        case displayText = "display_text"
        case sortIndex = "sort_index"
    }
}

struct LessonTargetUpdate: Codable {
    let lessonId: Int?
    let targetType: String?
    let vocabularyId: Int?
    let displayText: String?
    let sortIndex: Int?

    init(
        lessonId: Int? = nil,
        targetType: String? = nil,
        vocabularyId: Int? = nil,
        displayText: String? = nil,
        sortIndex: Int? = nil
    ) {
        self.lessonId = lessonId
        self.targetType = targetType
        self.vocabularyId = vocabularyId
        self.displayText = displayText
        self.sortIndex = sortIndex
    }

    // Backward-compatible initializer.
    init(
        lessonId: Int? = nil,
        targetType: String? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        displayText: String? = nil,
        sortIndex: Int? = nil
    ) {
        self.init(
            lessonId: lessonId,
            targetType: targetType,
            vocabularyId: wordId,
            displayText: displayText,
            sortIndex: sortIndex
        )
    }

    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case targetType = "target_type"
        case vocabularyId = "vocabulary_id"
        case displayText = "display_text"
        case sortIndex = "sort_index"
    }
}

struct LessonTargetUpsertSchema: Codable {
    let targetType: String
    let vocabularyId: Int?
    let displayText: String
    let sortIndex: Int

    init(
        targetType: String,
        vocabularyId: Int? = nil,
        displayText: String,
        sortIndex: Int
    ) {
        self.targetType = targetType
        self.vocabularyId = vocabularyId
        self.displayText = displayText
        self.sortIndex = sortIndex
    }

    // Backward-compatible initializer.
    init(
        targetType: String,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        displayText: String,
        sortIndex: Int
    ) {
        self.init(
            targetType: targetType,
            vocabularyId: wordId,
            displayText: displayText,
            sortIndex: sortIndex
        )
    }

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case vocabularyId = "vocabulary_id"
        case displayText = "display_text"
        case sortIndex = "sort_index"
    }
}

private enum LessonTargetDateParser {
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
