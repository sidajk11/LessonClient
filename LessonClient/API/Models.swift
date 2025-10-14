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
    var words: [Word] = []

    enum CodingKeys: String, CodingKey {
        case id
        case unit
        case level
        case grammar
        case translations
        case words
    }
}

struct LessonTranslation: Codable {
    let langCode: String
    let topic: String

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case topic
    }
}

struct LessonTranslationIn: Codable {
    let langCode: String
    let topic: String
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case topic
    }
}

// MARK: - Word (GET /words/*)
struct Word: Codable, Identifiable {
    let id: Int
    var lessonId: Int?   // detach 허용 시 서버 nullable
    var text: String
    var translations: [WordTranslation]
    var examples: [Example]

    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case text
        case translations
        case examples
    }
}

// WordTranslation은 (word_id, lang_code) 복합키 + meanings 목록
// 별도 id / text 컬럼 없음 → Identifiable 제거
struct WordTranslation: Codable {
    let langCode: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
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

struct WordCreate: Codable {
    let text: String
    let lessonId: Int?           // ✅ lesson_id 선택적
    let translations: [WordTranslation]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonId = "lesson_id"
        case translations
    }
}


// MARK: - Example (GET /examples/{id}, /examples/search)
struct Example: Codable, Identifiable {
    let id: Int
    let wordId: Int
    let wordText: String?
    let text: String
    let translations: [ExampleTranslation]

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case wordText = "word_text"
        case text
        case translations
    }
}

// (example_id, lang_code)가 복합 키이므로 별도 id 없음 → Identifiable 제거
struct ExampleTranslation: Codable {
    let langCode: String
    let text: String

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}

// MARK: - Exercise (서버 라우터 별도. 최소 형태 유지)
struct Exercise: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    var type: String
    var answer: String
    var options: [ExerciseOption]
    var translations: [ExerciseTranslation]

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case type
        case answer
        case options
        case translations
    }
}

// MARK: - ExerciseOption (응답용)
struct ExerciseOption: Codable, Identifiable {
    let id: Int
    var sortOrder: Int
    var text: String

    enum CodingKeys: String, CodingKey {
        case id
        case sortOrder = "sort_order"
        case text
    }
}

// MARK: - ExerciseTranslation (응답용)
// (exercise_id, lang_code) 복합 키라 별도 id 없음 → Identifiable 생략
struct ExerciseTranslation: Codable {
    let langCode: String
    let content: String?
    let question: String?

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case content
        case question
    }
}

struct ExerciseOptionIn: Codable {
    let sortOrder: Int
    let text: String

    enum CodingKeys: String, CodingKey {
        case sortOrder = "sort_order"
        case text
    }
}

struct ExerciseTranslationIn: Codable {
    let langCode: String
    let content: String?
    let question: String?

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case content
        case question
    }
}

