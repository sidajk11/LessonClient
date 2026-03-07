import Foundation

// MARK: - Example (GET /examples/{id}, /examples/search)
struct Example: Codable, Identifiable {
    let id: Int
    let sentence: String
    let vocabularyId: Int?
    let lessonTargetId: Int?
    let phraseId: Int?
    let wordText: String?
    let phraseText: String?
    let unit: Int?
    let translations: [ExampleTranslation]
    let exercises: [Exercise]
    let tokens: [SentenceTokenRead]

    enum CodingKeys: String, CodingKey {
        case id
        case sentence
        case vocabularyId = "vocabulary_id"
        case lessonTargetId = "lesson_target_id"
        case phraseId = "phrase_id"
        case wordText = "vocabulary_text"
        case phraseText = "phrase_text"
        case unit
        case translations
        case exercises
        case tokens
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        sentence = try c.decode(String.self, forKey: .sentence)
        vocabularyId = try c.decodeIfPresent(Int.self, forKey: .vocabularyId)
        lessonTargetId = try c.decodeIfPresent(Int.self, forKey: .lessonTargetId)
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        wordText = try c.decodeIfPresent(String.self, forKey: .wordText)
        phraseText = try c.decodeIfPresent(String.self, forKey: .phraseText)
        unit = try c.decodeIfPresent(Int.self, forKey: .unit)
        translations = try c.decodeIfPresent([ExampleTranslation].self, forKey: .translations) ?? []
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        tokens = try c.decodeIfPresent([SentenceTokenRead].self, forKey: .tokens) ?? []
    }
}

struct ExampleCreate: Codable {
    let sentence: String
    let vocabularyId: Int?
    let lessonTargetId: Int?
    let phraseId: Int?
    let translations: [ExampleTranslation]?

    enum CodingKeys: String, CodingKey {
        case sentence
        case vocabularyId = "vocabulary_id"
        case lessonTargetId = "lesson_target_id"
        case phraseId = "phrase_id"
        case translations
    }
}

struct ExampleUpdate: Codable {
    let sentence: String?
    let vocabularyId: Int?
    let lessonTargetId: Int?
    let phraseId: Int?
    let translations: [ExampleTranslation]?

    enum CodingKeys: String, CodingKey {
        case sentence
        case vocabularyId = "vocabulary_id"
        case lessonTargetId = "lesson_target_id"
        case phraseId = "phrase_id"
        case translations
    }

    init(
        sentence: String? = nil,
        vocabularyId: Int? = nil,
        lessonTargetId: Int? = nil,
        phraseId: Int? = nil,
        translations: [ExampleTranslation]? = nil
    ) {
        self.sentence = sentence
        self.vocabularyId = vocabularyId
        self.lessonTargetId = lessonTargetId
        self.phraseId = phraseId
        self.translations = translations
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
