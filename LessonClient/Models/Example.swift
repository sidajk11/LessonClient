import Foundation

// MARK: - Example (GET /examples/{id}, /examples/search)
struct Example: Codable, Identifiable {
    let id: Int
    let sentence: String
    let vocabularyId: Int?
    let phraseId: Int?
    let vocabularyText: String
    let phraseText: String
    let unit: Int?
    let translations: [ExampleTranslation]
    let exercises: [Exercise]
    let tokens: [SentenceTokenRead]

    var wordText: String? {
        let trimmed = vocabularyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sentence
        case vocabularyId = "vocabulary_id"
        case phraseId = "phrase_id"
        case vocabularyText = "vocabulary_text"
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
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        vocabularyText = try c.decodeIfPresent(String.self, forKey: .vocabularyText) ?? ""
        phraseText = try c.decodeIfPresent(String.self, forKey: .phraseText) ?? ""
        unit = try c.decodeIfPresent(Int.self, forKey: .unit)
        translations = try c.decodeIfPresent([ExampleTranslation].self, forKey: .translations) ?? []
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        tokens = try c.decodeIfPresent([SentenceTokenRead].self, forKey: .tokens) ?? []
    }
}

struct ExampleCreate: Codable {
    let sentence: String
    let vocabularyId: Int?
    let phraseId: Int?
    let translations: [ExampleTranslation]?

    enum CodingKeys: String, CodingKey {
        case sentence
        case vocabularyId = "vocabulary_id"
        case phraseId = "phrase_id"
        case translations
    }
}

struct ExampleUpdate: Codable {
    let sentence: String?
    let vocabularyId: Int?
    let phraseId: Int?
    let translations: [ExampleTranslation]?

    enum CodingKeys: String, CodingKey {
        case sentence
        case vocabularyId = "vocabulary_id"
        case phraseId = "phrase_id"
        case translations
    }

    init(
        sentence: String? = nil,
        vocabularyId: Int? = nil,
        phraseId: Int? = nil,
        translations: [ExampleTranslation]? = nil
    ) {
        self.sentence = sentence
        self.vocabularyId = vocabularyId
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
