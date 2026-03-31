//
//  ExampleSentence.swift
//  LessonClient
//
//  Created by 정영민 on 3/29/26.
//

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

// example_sentence 생성 payload입니다.
struct ExampleSentenceCreate: Codable {
    let exampleId: Int
    let order: Int?
    let type: String
    let speakerName: String?
    let text: String
    let translations: [ExampleSentenceTranslation]?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case order
        case type
        case speakerName = "speaker_name"
        case text
        case translations
    }

    init(
        exampleId: Int,
        order: Int? = nil,
        type: String = "sentence",
        speakerName: String? = nil,
        text: String,
        translations: [ExampleSentenceTranslation]? = nil
    ) {
        self.exampleId = exampleId
        self.order = order
        self.type = type
        self.speakerName = speakerName
        self.text = text
        self.translations = translations
    }
}

// example_sentence 수정 payload입니다.
struct ExampleSentenceUpdate: Codable {
    let exampleId: Int?
    let order: Int?
    let type: String?
    let speakerName: String?
    let text: String?
    let translations: [ExampleSentenceTranslation]?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case order
        case type
        case speakerName = "speaker_name"
        case text
        case translations
    }

    init(
        exampleId: Int? = nil,
        order: Int? = nil,
        type: String? = nil,
        speakerName: String? = nil,
        text: String? = nil,
        translations: [ExampleSentenceTranslation]? = nil
    ) {
        self.exampleId = exampleId
        self.order = order
        self.type = type
        self.speakerName = speakerName
        self.text = text
        self.translations = translations
    }
}

// example_sentence 번역 전체 치환 payload입니다.
struct ExampleSentenceTranslationsReplace: Codable {
    let translations: [ExampleSentenceTranslation]

    init(translations: [ExampleSentenceTranslation] = []) {
        self.translations = translations
    }
}
