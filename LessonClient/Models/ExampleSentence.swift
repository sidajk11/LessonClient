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
