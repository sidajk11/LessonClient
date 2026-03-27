import Foundation

struct ExampleSentence: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    let order: Int
    let type: String
    let speakerName: String?
    let text: String
    let tokens: [SentenceTokenRead]
    let exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case order
        case type
        case speakerName = "speaker_name"
        case text
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
    let translations: [ExampleTranslation]
    let exampleSentences: [ExampleSentence]
    let exercises: [Exercise]
    let tokens: [SentenceTokenRead]

    var wordText: String? {
        let trimmed = vocabularyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // 토큰 생성/수정 시 기준이 되는 주 문장을 고릅니다.
    var primarySentence: ExampleSentence? {
        if let exact = exampleSentences.first(where: { $0.text == sentence }) {
            return exact
        }
        return exampleSentences.sorted {
            if $0.order == $1.order {
                return $0.id < $1.id
            }
            return $0.order < $1.order
        }.first
    }

    var primarySentenceId: Int? {
        primarySentence?.id ?? id
    }

    private static func fallbackTokens(
        sentence: String,
        exampleSentences: [ExampleSentence]
    ) -> [SentenceTokenRead] {
        if let exact = exampleSentences.first(where: { $0.text == sentence }) {
            return exact.tokens
        }

        let primary = exampleSentences.sorted {
            if $0.order == $1.order {
                return $0.id < $1.id
            }
            return $0.order < $1.order
        }.first
        return primary?.tokens ?? []
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
        case exampleSentences = "example_sentences"
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
        exampleSentences = try c.decodeIfPresent([ExampleSentence].self, forKey: .exampleSentences) ?? []
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        let decodedTokens = try c.decodeIfPresent([SentenceTokenRead].self, forKey: .tokens) ?? []
        if !decodedTokens.isEmpty {
            tokens = decodedTokens
        } else {
            tokens = Self.fallbackTokens(sentence: sentence, exampleSentences: exampleSentences)
        }
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
