//
//  Phrase.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import Foundation

struct PhraseTranslationSchema: Codable, Hashable {
    let lang: String
    let text: String
}

struct PhraseRead: Codable, Identifiable {
    let id: Int
    let text: String
    let normalized: String
    let lessonTargetId: Int?
    let createdAt: String?
    let translations: [PhraseTranslationSchema]

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case normalized
        case lessonTargetId = "lesson_target_id"
        case createdAt = "created_at"
        case translations
    }
}

struct PhraseCreate: Codable {
    let text: String
    let lessonTargetId: Int?
    let translations: [PhraseTranslationSchema]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonTargetId = "lesson_target_id"
        case translations
    }
}

struct PhraseUpdate: Codable {
    let text: String?
    let lessonTargetId: Int?
    let translations: [PhraseTranslationSchema]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonTargetId = "lesson_target_id"
        case translations
    }
}

