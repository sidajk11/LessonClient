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
    var grammar: String?
    var translations: [LessonTranslation] = []
    var words: [Vocabulary] = []

    enum CodingKeys: String, CodingKey {
        case id
        case unit
        case level
        case grammar
        case translations
        case words = "vocabularies"
    }
}

struct LessonUpdate: Codable {
    let unit: Int?
    let level: Int?
    let grammar: String?
    let wordIds: [Int]?
    let translations: [LessonTranslation]?

    enum CodingKeys: String, CodingKey {
        case unit
        case level
        case grammar
        case wordIds = "vocabulary_ids"
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
    var translations: [VocabularyTranslation]
    var examples: [Example]

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case lessonId = "lesson_id"
        case translations
        case examples
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
    let text: String
    let wordId: Int
    let wordText: String?
    let translations: [ExampleTranslation]
    let practices: [Practice]

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case wordId = "vocabulary_id"
        case wordText = "vocabulary_text"
        case translations
        case practices
    }
}

struct ExampleUpdate: Codable {
    let text: String?
    let wordId: Int?
    let wordText: String?
    let translations: [ExampleTranslation]?
    let practices: [Practice]?

    enum CodingKeys: String, CodingKey {
        case text
        case wordId = "vocabulary_id"
        case wordText = "vocabulary_text"
        case translations
        case practices
    }
    
    init(text: String? = nil, wordId: Int? = nil, wordText: String? = nil, translations: [ExampleTranslation]? = nil, practices: [Practice]? = nil) {
        self.text = text
        self.wordId = wordId
        self.wordText = wordText
        self.translations = translations
        self.practices = practices
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
