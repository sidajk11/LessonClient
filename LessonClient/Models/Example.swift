import Foundation

struct ExampleSentence: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    let order: Int
    let type: String
    let speakerName: String?
    let text: String
    let translations: [ExampleSentenceTranslation]
    let tokens: [SentenceTokenRead]
    let exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case order
        case type
        case speakerName = "speaker_name"
        case text
        case translations
        case tokens
        case exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        exampleId = try c.decode(Int.self, forKey: .exampleId)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "sentence"
        speakerName = try c.decodeIfPresent(String.self, forKey: .speakerName)
        text = try c.decode(String.self, forKey: .text)
        translations = try c.decodeIfPresent([ExampleSentenceTranslation].self, forKey: .translations) ?? []
        tokens = try c.decodeIfPresent([SentenceTokenRead].self, forKey: .tokens) ?? []
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
    }
}

// MARK: - Example (GET /examples/{id}, /examples/search)
struct Example: Codable, Identifiable {
    let id: Int
    let sentence: String
    let vocabularyId: Int?
    let phraseId: Int?
    let vocabularyText: String
    let phraseText: String
    let unit: Int?
    let exampleSentences: [ExampleSentence]
    let exercises: [Exercise]

    var wordText: String? {
        let trimmed = vocabularyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var orderedExampleSentences: [ExampleSentence] {
        exampleSentences.sorted {
            if $0.order == $1.order {
                return $0.id < $1.id
            }
            return $0.order < $1.order
        }
    }

    // 토큰 생성/수정 시 기준이 되는 주 문장을 고릅니다.
    var primarySentence: ExampleSentence? {
        if let exact = exampleSentences.first(where: { $0.text == sentence }) {
            return exact
        }
        return orderedExampleSentences.first
    }

    var primarySentenceId: Int? {
        primarySentence?.id ?? id
    }

    var primaryTranslations: [ExampleSentenceTranslation] {
        primarySentence?.translations ?? []
    }

    var primaryTokens: [SentenceTokenRead] {
        primarySentence?.tokens ?? []
    }

    var allTokens: [SentenceTokenRead] {
        orderedExampleSentences.flatMap(\.tokens)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sentence
        case vocabularyId = "vocabulary_id"
        case phraseId = "phrase_id"
        case vocabularyText = "vocabulary_text"
        case phraseText = "phrase_text"
        case unit
        case exampleSentences = "example_sentences"
        case exercises
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
        exampleSentences = try c.decodeIfPresent([ExampleSentence].self, forKey: .exampleSentences) ?? []
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
    }

    init(
        id: Int,
        sentence: String,
        vocabularyId: Int?,
        phraseId: Int?,
        vocabularyText: String,
        phraseText: String,
        unit: Int?,
        exampleSentences: [ExampleSentence],
        exercises: [Exercise]
    ) {
        self.id = id
        self.sentence = sentence
        self.vocabularyId = vocabularyId
        self.phraseId = phraseId
        self.vocabularyText = vocabularyText
        self.phraseText = phraseText
        self.unit = unit
        self.exampleSentences = exampleSentences
        self.exercises = exercises
    }
}

struct ExampleCreate: Codable {
    let sentence: String
    let vocabularyId: Int?
    let phraseId: Int?
    let translations: [ExampleSentenceTranslation]?

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
    let translations: [ExampleSentenceTranslation]?

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
        translations: [ExampleSentenceTranslation]? = nil
    ) {
        self.sentence = sentence
        self.vocabularyId = vocabularyId
        self.phraseId = phraseId
        self.translations = translations
    }
}

struct ExampleSentenceTranslation: Codable {
    let langCode: LangCode
    var text: String

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}
