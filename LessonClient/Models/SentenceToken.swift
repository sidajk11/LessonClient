//
//  SentenceToken.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation

struct SentenceTokenRead: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    let tokenIndex: Int
    let surface: String
    let wordId: Int?
    let formId: Int?
    let senseId: Int?
    let pos: String?
    let startIndex: Int?
    let endIndex: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case tokenIndex = "token_index"
        case surface
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case pos
        case startIndex = "start_index"
        case endIndex = "end_index"
        case createdAt = "created_at"
    }
}

struct SentenceTokenCreate: Codable {
    let exampleId: Int
    let tokenIndex: Int
    let surface: String
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
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case pos
        case startIndex = "start_index"
        case endIndex = "end_index"
    }
}
