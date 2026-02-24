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
    var lessonTargetId: Int?
    var lessonTarget: LessonTargetRead?
    var translations: [VocabularyTranslation]
    var examples: [Example]?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case lessonId = "lesson_id"
        case lessonTargetId = "lesson_target_id"
        case lessonTarget = "lesson_target"
        case translations
        case examples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        lessonId = try c.decodeIfPresent(Int.self, forKey: .lessonId)
        lessonTargetId = try c.decodeIfPresent(Int.self, forKey: .lessonTargetId)
        lessonTarget = try c.decodeIfPresent(LessonTargetRead.self, forKey: .lessonTarget)
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
    let translations: [VocabularyTranslation]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonId = "lesson_id"
        case translations
    }
    
    init(text: String? = nil, lessonId: Int? = nil, translations: [VocabularyTranslation]? = nil) {
        self.text = text
        self.lessonId = lessonId
        self.translations = translations
    }
}


// MARK: - Example (GET /examples/{id}, /examples/search)
struct Example: Codable, Identifiable {
    let id: Int
    let sentence: String
    let vocabularyId: Int?
    let wordText: String?
    let translations: [ExampleTranslation]
    let exercises: [Exercise]?

    enum CodingKeys: String, CodingKey {
        case id
        case sentence
        case vocabularyId = "vocabulary_id"
        case wordText = "vocabulary_text"
        case translations
        case exercises
    }
}

struct ExampleUpdate: Codable {
    let sentence: String?
    let vocabularyId: Int?
    let wordText: String?
    let translations: [ExampleTranslation]?
    let exercises: [Exercise]?

    enum CodingKeys: String, CodingKey {
        case sentence
        case vocabularyId = "vocabulary_id"
        case wordText = "vocabulary_text"
        case translations
        case exercises
    }
    
    init(sentence: String? = nil, vocabularyId: Int? = nil, wordText: String? = nil, translations: [ExampleTranslation]? = nil, exercises: [Exercise]? = nil) {
        self.sentence = sentence
        self.vocabularyId = vocabularyId
        self.wordText = wordText
        self.translations = translations
        self.exercises = exercises
    }
}

struct ExampleTranslation: Codable {
    let langCode: LangCode
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}
