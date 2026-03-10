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

// MARK: - Vocabulary (GET /words/*)
struct Vocabulary: Codable, Identifiable {
    let id: Int
    var text: String
    var lessonId: Int?   // detach 허용 시 서버 nullable
    var wordId: Int?
    var formId: Int?
    var senseId: Int?
    var phraseId: Int?
    var translations: [VocabularyTranslation]
    var examples: [Example]?

    var lessonTargetId: Int? { nil }
    var lessonTarget: LessonTargetRead? { nil }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case lessonId = "lesson_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case phraseId = "phrase_id"
        case translations
        case examples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        lessonId = try c.decodeIfPresent(Int.self, forKey: .lessonId)
        wordId = try c.decodeIfPresent(Int.self, forKey: .wordId)
        formId = try c.decodeIfPresent(Int.self, forKey: .formId)
        senseId = try c.decodeIfPresent(Int.self, forKey: .senseId)
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        translations = try c.decodeIfPresent([VocabularyTranslation].self, forKey: .translations) ?? []
        examples = try c.decodeIfPresent([Example].self, forKey: .examples)
    }
}

struct VocabularyTranslation: Codable {
    let langCode: LangCode
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}

struct VocabularyUpdate: Codable {
    let text: String?
    let lessonId: Int?           // ✅ lesson_id 선택적
    let wordId: Int?
    let formId: Int?
    let senseId: Int?
    let phraseId: Int?
    let translations: [VocabularyTranslation]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonId = "lesson_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case phraseId = "phrase_id"
        case translations
    }
    
    init(
        text: String? = nil,
        lessonId: Int? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        phraseId: Int? = nil,
        translations: [VocabularyTranslation]? = nil
    ) {
        self.text = text
        self.lessonId = lessonId
        self.wordId = wordId
        self.formId = formId
        self.senseId = senseId
        self.phraseId = phraseId
        self.translations = translations
    }
}
