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
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case lang
        case text
        case isPrimary = "is_primary"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lang = try c.decode(String.self, forKey: .lang)
        text = try c.decode(String.self, forKey: .text)
        isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? true
    }
}

struct SentenceTokenWordSenseRead: Codable, Hashable, Identifiable {
    let id: Int
    let wordId: Int
    let senseCode: String
    let pos: String?
    let explain: String
    let cefr: String?

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case senseCode = "sense_code"
        case pos
        case explain
        case cefr
    }
}

struct SentenceTokenVocabularyRead: Codable, Hashable, Identifiable {
    let id: Int
    let text: String
    let unit: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case unit
    }
}

struct SentenceTokenRead: Codable, Identifiable {
    let id: Int
    let exampleSentenceId: Int
    let tokenIndex: Int
    let surface: String
    let phraseId: Int?
    let wordId: Int?
    let formId: Int?
    let sense: SentenceTokenWordSenseRead?
    let pos: String?
    let startIndex: Int?
    let endIndex: Int?
    let translations: [SentenceTokenTranslationRead]
    let vocabulary: SentenceTokenVocabularyRead?
    let createdAt: Date?
    private let rawSenseId: Int?

    var exampleId: Int { exampleSentenceId }
    var senseId: Int? { sense?.id ?? rawSenseId }

    enum CodingKeys: String, CodingKey {
        case id
        case exampleSentenceId = "example_sentence_id"
        case legacyExampleId = "example_id"
        case tokenIndex = "token_index"
        case surface
        case phraseId = "phrase_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case sense
        case pos
        case startIndex = "start_index"
        case endIndex = "end_index"
        case translations
        case vocabulary
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        exampleSentenceId =
            try c.decodeIfPresent(Int.self, forKey: .exampleSentenceId) ??
            c.decode(Int.self, forKey: .legacyExampleId)
        tokenIndex = try c.decode(Int.self, forKey: .tokenIndex)
        surface = try c.decode(String.self, forKey: .surface)
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        wordId = try c.decodeIfPresent(Int.self, forKey: .wordId)
        formId = try c.decodeIfPresent(Int.self, forKey: .formId)
        sense = try c.decodeIfPresent(SentenceTokenWordSenseRead.self, forKey: .sense)
        rawSenseId = try c.decodeIfPresent(Int.self, forKey: .senseId)
        pos = try c.decodeIfPresent(String.self, forKey: .pos)
        startIndex = try c.decodeIfPresent(Int.self, forKey: .startIndex)
        endIndex = try c.decodeIfPresent(Int.self, forKey: .endIndex)
        translations = try c.decodeIfPresent([SentenceTokenTranslationRead].self, forKey: .translations) ?? []
        vocabulary = try c.decodeIfPresent(SentenceTokenVocabularyRead.self, forKey: .vocabulary)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(exampleSentenceId, forKey: .exampleSentenceId)
        try c.encode(tokenIndex, forKey: .tokenIndex)
        try c.encode(surface, forKey: .surface)
        try c.encodeIfPresent(phraseId, forKey: .phraseId)
        try c.encodeIfPresent(wordId, forKey: .wordId)
        try c.encodeIfPresent(formId, forKey: .formId)
        try c.encodeIfPresent(senseId, forKey: .senseId)
        try c.encodeIfPresent(sense, forKey: .sense)
        try c.encodeIfPresent(pos, forKey: .pos)
        try c.encodeIfPresent(startIndex, forKey: .startIndex)
        try c.encodeIfPresent(endIndex, forKey: .endIndex)
        try c.encode(translations, forKey: .translations)
        try c.encodeIfPresent(vocabulary, forKey: .vocabulary)
        try c.encodeIfPresent(createdAt.map(LessonClientDateCoding.string), forKey: .createdAt)
    }
}

struct SentenceTokenCreate: Codable {
    let exampleSentenceId: Int
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
        case exampleSentenceId = "example_sentence_id"
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
    let exampleSentenceId: Int?
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
        case exampleSentenceId = "example_sentence_id"
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
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case lang
        case text
        case isPrimary = "is_primary"
    }
}
