// Models.swift
import Foundation

struct Empty: Codable {}

struct User: Codable, Identifiable {
    let id: Int
    let email: String
}

// MARK: - Lesson (GET /lessons, /lessons/{id})
struct Lesson: Codable, Identifiable {
    let id: Int
    var unit: Int                 // ✅ Int로 직접 보유
    var level: Int                // ✅ Int로 직접 보유
    var trackCode: String
    var grammar: String?
    var lessonTargets: [LessonTargetRead] = []
    var translations: [LessonTranslation] = []
    var vocabularies: [Vocabulary] = []

    enum CodingKeys: String, CodingKey {
        case id
        case unit
        case level
        case trackCode = "track_code"
        case grammar
        case lessonTargets = "lesson_targets"
        case translations
        case vocabularies = "vocabularies"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        unit = try c.decode(Int.self, forKey: .unit)
        level = try c.decode(Int.self, forKey: .level)
        trackCode = try c.decodeIfPresent(String.self, forKey: .trackCode) ?? "en-US"
        grammar = try c.decodeIfPresent(String.self, forKey: .grammar)
        lessonTargets = try c.decodeIfPresent([LessonTargetRead].self, forKey: .lessonTargets) ?? []
        translations = try c.decodeIfPresent([LessonTranslation].self, forKey: .translations) ?? []
        vocabularies = try c.decodeIfPresent([Vocabulary].self, forKey: .vocabularies) ?? []
    }
}

struct LessonUpdate: Codable {
    let unit: Int?
    let level: Int?
    let trackCode: String?
    let grammar: String?
    let vocabularyIds: [Int]?
    let lessonTargets: [LessonTargetUpsertSchema]?
    let translations: [LessonTranslation]?

    enum CodingKeys: String, CodingKey {
        case unit
        case level
        case trackCode = "track_code"
        case grammar
        case vocabularyIds = "vocabulary_ids"
        case lessonTargets = "lesson_targets"
        case translations
    }
}

struct LessonTranslation: Codable {
    let langCode: LangCode
    var topic: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case topic
    }
}

