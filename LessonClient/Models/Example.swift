import Foundation



// MARK: - Example (GET /examples/{id}, /examples/search)
struct Example: Codable, Identifiable {
    let id: Int
    let createdAt: Date?
    let isActive: Bool
    let tokensNeedFix: Bool
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

    var firstExampleSentence: ExampleSentence? {
        orderedExampleSentences.first
    }

    var allTokens: [SentenceTokenRead] {
        orderedExampleSentences.flatMap(\.tokens)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case isActive = "is_active"
        case tokensNeedFix = "tokens_need_fix"
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
        // 서버가 ISO8601 문자열을 내려주므로 문자열로 받아서 파싱합니다.
        let createdAtRaw = try c.decodeIfPresent(String.self, forKey: .createdAt)
        createdAt = ExampleDateParser.parse(createdAtRaw)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        tokensNeedFix = try c.decodeIfPresent(Bool.self, forKey: .tokensNeedFix) ?? false
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
        createdAt: Date? = nil,
        isActive: Bool = true,
        tokensNeedFix: Bool = false,
        vocabularyId: Int?,
        phraseId: Int?,
        vocabularyText: String,
        phraseText: String,
        unit: Int?,
        exampleSentences: [ExampleSentence],
        exercises: [Exercise]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.isActive = isActive
        self.tokensNeedFix = tokensNeedFix
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
    let vocabularyId: Int?
    let phraseId: Int?
    let isActive: Bool
    let translations: [ExampleSentenceTranslation]?

    enum CodingKeys: String, CodingKey {
        case vocabularyId = "vocabulary_id"
        case phraseId = "phrase_id"
        case isActive = "is_active"
        case translations
    }

    init(
        vocabularyId: Int? = nil,
        phraseId: Int? = nil,
        isActive: Bool = true,
        translations: [ExampleSentenceTranslation]? = nil
    ) {
        self.vocabularyId = vocabularyId
        self.phraseId = phraseId
        self.isActive = isActive
        self.translations = translations
    }
}

struct ExampleUpdate: Codable {
    let vocabularyId: Int?
    let phraseId: Int?
    let isActive: Bool?
    let translations: [ExampleSentenceTranslation]?

    enum CodingKeys: String, CodingKey {
        case vocabularyId = "vocabulary_id"
        case phraseId = "phrase_id"
        case isActive = "is_active"
        case translations
    }

    init(
        vocabularyId: Int? = nil,
        phraseId: Int? = nil,
        isActive: Bool? = nil,
        translations: [ExampleSentenceTranslation]? = nil
    ) {
        self.vocabularyId = vocabularyId
        self.phraseId = phraseId
        self.isActive = isActive
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

private enum ExampleDateParser {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return iso8601WithFractional.date(from: raw) ?? iso8601.date(from: raw)
    }

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
