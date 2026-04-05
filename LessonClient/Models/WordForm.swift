//
//  WordForm.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import Foundation

// MARK: - Translation

struct WordFormTranslationSchema: Codable, Hashable {
    let lang: String
    let explain: String

    enum CodingKeys: String, CodingKey {
        case lang
        case explain
    }
}

// MARK: - Read

struct WordFormRead: Codable, Identifiable, Hashable {
    let id: Int
    let createdAt: Date?
    let updatedAt: Date?
    let wordId: Int
    let derivedWordId: Int?
    let form: String
    let formType: String?
    let translations: [WordFormTranslationSchema]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case wordId = "word_id"
        case derivedWordId = "derived_word_id"
        case form
        case formType = "form_type"
        case translations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        wordId = try c.decode(Int.self, forKey: .wordId)
        derivedWordId = try c.decodeIfPresent(Int.self, forKey: .derivedWordId)
        form = try c.decode(String.self, forKey: .form)
        formType = try c.decodeIfPresent(String.self, forKey: .formType)
        translations = try c.decodeIfPresent([WordFormTranslationSchema].self, forKey: .translations) ?? []
    }

    init(
        id: Int,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        wordId: Int,
        derivedWordId: Int? = nil,
        form: String,
        formType: String?,
        translations: [WordFormTranslationSchema] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.wordId = wordId
        self.derivedWordId = derivedWordId
        self.form = form
        self.formType = formType
        self.translations = translations
    }
}

// MARK: - Create

struct WordFormCreate: Codable {
    let wordId: Int
    let derivedWordId: Int?
    let form: String
    let formType: String?
    let translations: [WordFormTranslationSchema]?

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
        case derivedWordId = "derived_word_id"
        case form
        case formType = "form_type"
        case translations
    }
}

// MARK: - Update

struct WordFormUpdate: Codable {
    let wordId: Int?
    let derivedWordId: Int?
    let form: String?
    let formType: String?
    let translations: [WordFormTranslationSchema]?

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
        case derivedWordId = "derived_word_id"
        case form
        case formType = "form_type"
        case translations
    }
}
