//
//  PracticeModel.swift
//  LessonClient
//
//  Created by ymj on 10/15/25.
//

struct Exercise: Codable, Identifiable {
    let id: Int
    let exampleId: Int

    let type: ExerciseType

    let prompt: String?
    let explanation: String?
    let timeLimitSec: Int?

    let options: [ExerciseOption]

    let correctOptionId: Int?
    let correctOptionIds: [Int]?
    let correctGroupId: Int?

    let expectedAnswers: [ExpectedAnswer]?
    let translations: [ExerciseTranslation]?

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case type
        case prompt
        case explanation
        case timeLimitSec = "time_limit_sec"
        case options
        case correctOptionId = "correct_option_id"
        case expectedAnswers = "expected_answers"
        case correctOptionIds = "correct_option_ids"
        case correctGroupId = "correct_group_id"
        case translations
    }
}

// MARK: - Update payload

struct ExerciseUpdate: Codable {
    let exampleId: Int

    var type: ExerciseType?
    var prompt: String?
    var explanation: String?
    var timeLimitSec: Int?

    var options: [ExerciseOptionUpdate]?

    var correctOptionIds: [Int]?
    var correctGroupId: Int?

    var expectedAnswers: [ExpectedAnswer]?
    var translations: [ExerciseTranslation]?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case type
        case prompt
        case explanation
        case timeLimitSec = "time_limit_sec"
        case options
        case correctOptionIds = "correct_option_ids"
        case correctGroupId = "correct_group_id"
        case expectedAnswers = "expected_answers"
        case translations
    }
}

// MARK: - Option

enum ExerciseOptionKind: String, Codable {
    case word
    case sentence
    case image
    case audio
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        self = ExerciseOptionKind(rawValue: raw) ?? .unknown
    }
}

struct ExerciseOption: Codable, Identifiable {
    var id: Int

    let optionKind: ExerciseOptionKind
    let position: Int
    let isDistractor: Bool?

    let audioURL: String?
    let imageURL: String?

    var text: String

    enum CodingKeys: String, CodingKey {
        case id
        case optionKind = "option_kind"
        case position
        case isDistractor = "is_distractor"
        case audioURL = "audio_url"
        case imageURL = "image_url"
        case text
    }
}

struct ExerciseOptionUpdate: Codable {
    var optionKind: ExerciseOptionKind?
    var position: Int?
    var isDistractor: Bool?
    var audioURL: String?
    var imageURL: String?
    var text: String?

    enum CodingKeys: String, CodingKey {
        case optionKind = "option_kind"
        case position
        case isDistractor = "is_distractor"
        case audioURL = "audio_url"
        case imageURL = "image_url"
        case text
    }
}

// MARK: - Root translations

struct ExerciseTranslation: Codable {
    let langCode: LangCode
    var question: String?
    var hint: String?
    var explanation: String?

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case question
        case hint
        case explanation
    }
}

// MARK: - Expected Answers

enum GradingRule: String, Codable {
    case exact
    case contains
    case regex
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        self = GradingRule(rawValue: raw) ?? .unknown
    }
}

struct ExpectedAnswer: Codable {
    let langCode: LangCode
    let answerText: String
    let normalizedAnswer: String?
    let altAnswersJson: [String]?
    let gradingRule: GradingRule?
    let gradingConfigJson: JSONValue?

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case answerText = "answer_text"
        case normalizedAnswer = "normalized_answer"
        case altAnswersJson = "alt_answers_json"
        case gradingRule = "grading_rule"
        case gradingConfigJson = "grading_config_json"
    }
}

/// grading_config_json 같은 "임의 구조 JSON"을 안전하게 담기 위한 타입
enum JSONValue: Codable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()

        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }

        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSONValue")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        }
    }
}
