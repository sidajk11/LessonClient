//
//  SentenceToken.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation

struct SentenceTokenTranslationRead: Codable, Hashable {
    let lang: String
    let text: String
}

struct SentenceTokenRead: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    let tokenIndex: Int
    let surface: String
    let phraseId: Int?
    let wordId: Int?
    let formId: Int?
    let senseId: Int?
    let pos: String?
    let startIndex: Int?
    let endIndex: Int?
    let translations: [SentenceTokenTranslationRead]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case tokenIndex = "token_index"
        case surface
        case phraseId = "phrase_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case pos
        case startIndex = "start_index"
        case endIndex = "end_index"
        case translations
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        exampleId = try c.decode(Int.self, forKey: .exampleId)
        tokenIndex = try c.decode(Int.self, forKey: .tokenIndex)
        surface = try c.decode(String.self, forKey: .surface)
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        wordId = try c.decodeIfPresent(Int.self, forKey: .wordId)
        formId = try c.decodeIfPresent(Int.self, forKey: .formId)
        senseId = try c.decodeIfPresent(Int.self, forKey: .senseId)
        pos = try c.decodeIfPresent(String.self, forKey: .pos)
        startIndex = try c.decodeIfPresent(Int.self, forKey: .startIndex)
        endIndex = try c.decodeIfPresent(Int.self, forKey: .endIndex)
        translations = try c.decodeIfPresent([SentenceTokenTranslationRead].self, forKey: .translations) ?? []

        let createdAtRaw = try c.decodeIfPresent(String.self, forKey: .createdAt)
        createdAt = SentenceTokenDateParser.parse(createdAtRaw)
    }
}

struct SentenceTokenCreate: Codable {
    let exampleId: Int
    let tokenIndex: Int
    let surface: String
    let phraseId: Int?
    let wordId: Int?
    let formId: Int?
    let senseId: Int?
    let pos: String?
    let startIndex: Int?
    let endIndex: Int?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case tokenIndex = "token_index"
        case surface
        case phraseId = "phrase_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case pos
        case startIndex = "start_index"
        case endIndex = "end_index"
    }
}

struct SentenceTokenUpdate: Codable {
    let exampleId: Int?
    let tokenIndex: Int?
    let surface: String?
    let phraseId: Int?
    let wordId: Int?
    let formId: Int?
    let senseId: Int?
    let pos: String?
    let startIndex: Int?
    let endIndex: Int?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case tokenIndex = "token_index"
        case surface
        case phraseId = "phrase_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case pos
        case startIndex = "start_index"
        case endIndex = "end_index"
    }
}

struct SentenceTokenTranslationCreate: Codable {
    let lang: String
    let text: String
}

private enum SentenceTokenDateParser {
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
