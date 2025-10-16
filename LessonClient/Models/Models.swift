// Models.swift
import Foundation

struct Empty: Codable {}

struct LocalizedText: Codable {
    let langCode: String
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}

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
    var topic: [LocalizedText] = []
    var words: [Word] = []

    enum CodingKeys: String, CodingKey {
        case id
        case unit
        case level
        case grammar
        case topic
        case words
    }
}

struct LessonUpdate: Codable {
    let unit: Int?
    let level: Int?
    let grammar: String?
    let topic: [LocalizedText]?
    let wordIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case unit
        case level
        case grammar
        case topic
        case wordIds = "word_ids"
    }
}

// MARK: - Word (GET /words/*)
struct Word: Codable, Identifiable {
    let id: Int
    var lessonId: Int?   // detach 허용 시 서버 nullable
    var text: String
    var translation: [LocalizedText]
    var examples: [Example]

    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case text
        case translation
        case examples
    }
}


// 목록 응답 (GET /words/lessons/{lesson_id})
struct WordRow: Codable, Identifiable {
    let id: Int
    let text: String
    let translation: String?

    enum CodingKeys: String, CodingKey {
        case id, text, translation
    }
}

struct WordList: Codable {
    let total: Int
    let items: [WordRow]
}

struct WordUpdate: Codable {
    let text: String?
    let lessonId: Int?           // ✅ lesson_id 선택적
    let translation: [LocalizedText]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonId = "lesson_id"
        case translation
    }
    
    init(text: String? = nil, lessonId: Int? = nil, translation: [LocalizedText]? = nil) {
        self.text = text
        self.lessonId = lessonId
        self.translation = translation
    }
}


// MARK: - Example (GET /examples/{id}, /examples/search)
struct Example: Codable, Identifiable {
    let id: Int
    let wordId: Int
    let wordText: String?
    let text: String
    let translation: [LocalizedText]
    let exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case wordText = "word_text"
        case text
        case translation
        case exercises
    }
}

struct ExampleUpdate: Codable {
    let wordId: Int?
    let wordText: String?
    let text: String?
    let translation: [LocalizedText]?
    let exercises: [Exercise]?

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
        case wordText = "word_text"
        case text
        case translation
        case exercises
    }
    
    init(wordId: Int? = nil, wordText: String? = nil, text: String? = nil, translation: [LocalizedText]? = nil, exercises: [Exercise]? = nil) {
        self.wordId = wordId
        self.wordText = wordText
        self.text = text
        self.translation = translation
        self.exercises = exercises
    }
}

