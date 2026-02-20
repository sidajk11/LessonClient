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
    let wordId: Int
    let form: String
    let formType: String?
    let translations: [WordFormTranslationSchema]

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case form
        case formType = "form_type"
        case translations
    }

    // 서버 기본값이 [] 이지만, 혹시 null이 올 가능성 방어
    init(
        id: Int,
        wordId: Int,
        form: String,
        formType: String?,
        translations: [WordFormTranslationSchema] = []
    ) {
        self.id = id
        self.wordId = wordId
        self.form = form
        self.formType = formType
        self.translations = translations
    }
}

// MARK: - Create

struct WordFormCreate: Codable {
    let wordId: Int
    let form: String
    let formType: String?
    let translations: [WordFormTranslationSchema]?

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
        case form
        case formType = "form_type"
        case translations
    }
}

// MARK: - Update

struct WordFormUpdate: Codable {
    let wordId: Int?
    let form: String?
    let formType: String?
    let translations: [WordFormTranslationSchema]?

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
        case form
        case formType = "form_type"
        case translations
    }
}
