//
//  ExerciseModel.swift
//  LessonClient
//
//  Created by ymj on 10/15/25.
//

import Foundation

// 서버 응답을 읽고 필요 시 다시 인코드할 수 있는 exercise 모델입니다.
struct Exercise: Codable, Identifiable {
    let id: Int
    let exampleId: Int?
    let targetSentences: [ExerciseTargetSentence]
    let blanks: [ExerciseBlank]
    let vocabularyId: Int?
    let vocabularyIds: [Int]

    let type: ExerciseType
    let status: String

    let prompt: String?
    let timeLimitSec: Int?
    let translation: String
    let sentence: String?
    let tokens: [SentenceTokenRead]

    let options: [ExerciseOption]
    let correctOptions: [ExerciseCorrectOption]

    let expectedAnswers: [ExpectedAnswer]
    let translations: [ExerciseTranslation]

    var lessonTargetId: Int? { vocabularyId }

    // tokens + blanks로 화면 표시용 prompt를 복원합니다.
    var displayPrompt: String {
        if let blanksPrompt, !blanksPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return blanksPrompt
        }
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return prompt
        }
        if let sentence, !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sentence
        }
        return ""
    }

    private var blanksPrompt: String? {
        guard !tokens.isEmpty, !blanks.isEmpty else { return nil }

        let blankByTokenId = Dictionary(uniqueKeysWithValues: blanks.map { ($0.sentenceTokenId, $0) })
        let promptTokens = tokens
            .sorted { $0.tokenIndex < $1.tokenIndex }
            .map { token -> String in
                guard let blank = blankByTokenId[token.id] else {
                    return token.surface
                }
                let slotCount = max(blank.blankSlotCount, 1)
                return Array(repeating: "_", count: slotCount).joined(separator: " ")
            }

        return promptTokens.joinTokens()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case targetSentences = "target_sentences"
        case vocabularyId = "vocabulary_id"
        case vocabularyIds = "vocabulary_ids"
        case type
        case status
        case prompt
        case timeLimitSec = "time_limit_sec"
        case translation
        case sentence
        case tokens
        case options
        case expectedAnswers = "expected_answers"
        case correctOptions = "correct_options"
        case blanks
        case translations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        exampleId = try c.decodeIfPresent(Int.self, forKey: .exampleId)
        targetSentences = try c.decodeIfPresent([ExerciseTargetSentence].self, forKey: .targetSentences) ?? []
        blanks = try c.decodeIfPresent([ExerciseBlank].self, forKey: .blanks) ?? []
        vocabularyId = try c.decodeIfPresent(Int.self, forKey: .vocabularyId)
        vocabularyIds = try c.decodeIfPresent([Int].self, forKey: .vocabularyIds) ?? []
        type = try c.decode(ExerciseType.self, forKey: .type)
        // 서버 응답이 단계적으로 바뀌는 동안에도 기본 상태로 안전하게 처리합니다.
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "draft"
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt)
        timeLimitSec = try c.decodeIfPresent(Int.self, forKey: .timeLimitSec)
        translation = try c.decodeIfPresent(String.self, forKey: .translation) ?? ""
        sentence = try c.decodeIfPresent(String.self, forKey: .sentence)
        tokens = try c.decodeIfPresent([SentenceTokenRead].self, forKey: .tokens) ?? []
        options = try c.decodeIfPresent([ExerciseOption].self, forKey: .options) ?? []
        expectedAnswers = try c.decodeIfPresent([ExpectedAnswer].self, forKey: .expectedAnswers) ?? []
        correctOptions = try c.decodeIfPresent([ExerciseCorrectOption].self, forKey: .correctOptions) ?? []
        translations = try c.decodeIfPresent([ExerciseTranslation].self, forKey: .translations) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(exampleId, forKey: .exampleId)
        try c.encode(targetSentences, forKey: .targetSentences)
        try c.encode(blanks, forKey: .blanks)
        try c.encodeIfPresent(vocabularyId, forKey: .vocabularyId)
        try c.encode(vocabularyIds, forKey: .vocabularyIds)
        try c.encode(type, forKey: .type)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(prompt, forKey: .prompt)
        try c.encodeIfPresent(timeLimitSec, forKey: .timeLimitSec)
        try c.encode(translation, forKey: .translation)
        try c.encodeIfPresent(sentence, forKey: .sentence)
        try c.encode(tokens, forKey: .tokens)
        try c.encode(options, forKey: .options)
        try c.encode(expectedAnswers, forKey: .expectedAnswers)
        try c.encode(correctOptions, forKey: .correctOptions)
        try c.encode(translations, forKey: .translations)
    }
}

// MARK: - Create / Update payload

struct ExerciseCreate: Codable {
    var exampleId: Int?
    var targetSentenceIds: [Int]? = nil
    var vocabularyId: Int?
    var type: ExerciseType
    var status: String = "draft"
    var vocabularyIds: [Int]?

    var prompt: String?
    var timeLimitSec: Int?

    var options: [ExerciseOptionUpdate]?

    var correctOptionIds: [Int]?
    var correctGroupId: Int? = 0

    var expectedAnswers: [ExpectedAnswer]?
    var translations: [ExerciseTranslation] = []

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case targetSentenceIds = "target_sentence_ids"
        case vocabularyId = "vocabulary_id"
        case type
        case status
        case vocabularyIds = "vocabulary_ids"
        case prompt
        case timeLimitSec = "time_limit_sec"
        case options
        case correctOptionIds = "correct_option_ids"
        case correctGroupId = "correct_group_id"
        case expectedAnswers = "expected_answers"
        case translations
    }
}

struct ExerciseUpdate: Codable {
    var exampleId: Int?
    var targetSentenceIds: [Int]? = nil
    var vocabularyId: Int?

    var type: ExerciseType?
    var status: String?
    var vocabularyIds: [Int]?
    var prompt: String?
    var timeLimitSec: Int?

    var options: [ExerciseOptionUpdate]?

    var correctOptionIds: [Int]?
    var correctGroupId: Int? = 0

    var expectedAnswers: [ExpectedAnswer]?
    var translations: [ExerciseTranslation]?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case targetSentenceIds = "target_sentence_ids"
        case vocabularyId = "vocabulary_id"
        case type
        case status
        case vocabularyIds = "vocabulary_ids"
        case prompt
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

// 서버 응답을 읽고 필요 시 다시 인코드할 수 있는 option 모델입니다.
struct ExerciseOption: Codable, Identifiable {
    var id: Int

    let optionKind: ExerciseOptionKind
    let position: Int
    let isDistractor: Bool?

    let audioURL: String?
    let imageURL: String?
    let explanation: String?

    private let rawText: String?
    private let rawDisplayText: String?
    let translations: [ExerciseOptionTranslation]

    enum CodingKeys: String, CodingKey {
        case id
        case optionKind = "option_kind"
        case position
        case isDistractor = "is_distractor"
        case audioURL = "audio_url"
        case imageURL = "image_url"
        case text
        case displayText = "display_text"
        case explanation
        case translations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        optionKind = try c.decode(ExerciseOptionKind.self, forKey: .optionKind)
        position = try c.decode(Int.self, forKey: .position)
        isDistractor = try c.decodeIfPresent(Bool.self, forKey: .isDistractor)
        audioURL = try c.decodeIfPresent(String.self, forKey: .audioURL)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation)
        translations = try c.decodeIfPresent([ExerciseOptionTranslation].self, forKey: .translations) ?? []
        rawText = try c.decodeIfPresent(String.self, forKey: .text)
        rawDisplayText = try c.decodeIfPresent(String.self, forKey: .displayText)
    }

    var text: String {
        if let rawText, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawText
        }
        if let rawDisplayText, !rawDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawDisplayText
        }
        return translations.first?.displayText ?? translations.first?.text ?? ""
    }

    var displayText: String {
        if let rawDisplayText, !rawDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawDisplayText
        }
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        if let enUS = translations.first(where: { $0.langCode.caseInsensitiveCompare("en-US") == .orderedSame }) {
            return enUS.displayText ?? enUS.text ?? ""
        }
        if let en = translations.first(where: { $0.langCode.caseInsensitiveCompare("en") == .orderedSame }) {
            return en.displayText ?? en.text ?? ""
        }
        if let ko = translations.first(where: { $0.langCode.caseInsensitiveCompare("ko") == .orderedSame }) {
            return ko.displayText ?? ko.text ?? ""
        }
        return translations.first?.displayText ?? translations.first?.text ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(optionKind, forKey: .optionKind)
        try c.encode(position, forKey: .position)
        try c.encodeIfPresent(isDistractor, forKey: .isDistractor)
        try c.encodeIfPresent(audioURL, forKey: .audioURL)
        try c.encodeIfPresent(imageURL, forKey: .imageURL)
        try c.encode(text, forKey: .text)
        try c.encode(displayText, forKey: .displayText)
        try c.encodeIfPresent(explanation, forKey: .explanation)
        try c.encode(translations, forKey: .translations)
    }
}

struct ExerciseOptionUpdate: Codable {
    var optionKind: ExerciseOptionKind?
    var position: Int?
    var isDistractor: Bool?
    var audioURL: String?
    var imageURL: String?
    var translations: [ExerciseOptionTranslation]?

    enum CodingKeys: String, CodingKey {
        case optionKind = "option_kind"
        case position
        case isDistractor = "is_distractor"
        case audioURL = "audio_url"
        case imageURL = "image_url"
        case translations
    }

    static func textOption(_ text: String, langCode: String = LangCode.enUS.rawValue) -> ExerciseOptionUpdate {
        ExerciseOptionUpdate(
            translations: [ExerciseOptionTranslation(langCode: langCode, text: text, displayText: text, explanation: nil)]
        )
    }
}

struct ExerciseOptionTranslation: Codable {
    var langCode: String
    var text: String?
    var displayText: String?
    var explanation: String?

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
        case displayText = "display_text"
        case explanation
    }
}

struct ExerciseCorrectOption: Codable, Identifiable {
    let id: Int
    let optionId: Int
    let groupId: Int
    let position: Int
    let option: ExerciseOption?

    enum CodingKeys: String, CodingKey {
        case id
        case optionId = "option_id"
        case groupId = "group_id"
        case position
        case option
    }
}

struct ExerciseBlank: Codable, Identifiable {
    let id: Int
    let exerciseId: Int
    let sentenceTokenId: Int
    let blankOrder: Int
    let displayType: String?
    let blankSlotCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case sentenceTokenId = "sentence_token_id"
        case blankOrder = "blank_order"
        case displayType = "display_type"
        case blankSlotCount = "blank_slot_count"
    }
}

struct ExerciseTargetSentence: Codable, Identifiable {
    let id: Int
    let exampleSentenceId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case exampleSentenceId = "example_sentence_id"
    }
}

// MARK: - Replace payloads

struct OptionsReplace: Codable {
    var options: [ExerciseOptionUpdate]
}

struct ContentReplace: Codable {
    var translations: [ExerciseTranslation]
}

struct ExpectedAnswersReplace: Codable {
    var expectedAnswers: [ExpectedAnswer] = []

    enum CodingKeys: String, CodingKey {
        case expectedAnswers = "expected_answers"
    }
}

struct CorrectOptionsReplace: Codable {
    var correctOptionIds: [Int] = []
    var correctGroupId: Int = 0

    enum CodingKeys: String, CodingKey {
        case correctOptionIds = "correct_option_ids"
        case correctGroupId = "correct_group_id"
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
    let altAnswersJson: [String]
    let gradingRule: GradingRule
    let gradingConfigJson: JSONValue

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case answerText = "answer_text"
        case normalizedAnswer = "normalized_answer"
        case altAnswersJson = "alt_answers_json"
        case gradingRule = "grading_rule"
        case gradingConfigJson = "grading_config_json"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        langCode = try c.decode(LangCode.self, forKey: .langCode)
        answerText = try c.decode(String.self, forKey: .answerText)
        normalizedAnswer = try c.decodeIfPresent(String.self, forKey: .normalizedAnswer)
        altAnswersJson = try c.decodeIfPresent([String].self, forKey: .altAnswersJson) ?? []
        gradingRule = try c.decodeIfPresent(GradingRule.self, forKey: .gradingRule) ?? .exact
        gradingConfigJson = try c.decodeIfPresent(JSONValue.self, forKey: .gradingConfigJson) ?? .object([:])
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
