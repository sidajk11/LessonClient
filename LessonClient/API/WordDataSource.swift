//
//  WordDataSource.swift
//  LessonClient
//
//  Created by ymj on 10/01/25
//

import Foundation

final class WordDataSource {
    static let shared = WordDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Create Word
    @discardableResult
    func createWord(text: String, lessonId: Int? = nil, translations: [WordTranslationIn]? = nil) async throws -> WordOut {
        let body = WordCreate(text: text, lessonId: lessonId, translations: translations)
        return try await api.request("POST", "/words", jsonBody: body, as: WordOut.self)
    }

    // MARK: - Fetch Words
    func words(lang: String = "ko") async throws -> [WordOut] {
        try await api.request("GET", "/words?lang=\(lang)", as: [WordOut].self)
    }

    func word(id: Int, lang: String = "ko") async throws -> WordOut {
        try await api.request("GET", "/words/\(id)?lang=\(lang)", as: WordOut.self)
    }

    // MARK: - Update Word
    @discardableResult
    func updateWord(id: Int, text: String? = nil, lessonId: Int? = nil, translations: [WordTranslationIn]? = nil) async throws -> WordOut {
        struct WordUpdate: Codable {
            let text: String?
            let lessonId: Int?
            let translations: [WordTranslationIn]?

            enum CodingKeys: String, CodingKey {
                case text
                case lessonId = "lesson_id"
                case translations
            }
        }

        let body = WordUpdate(text: text, lessonId: lessonId, translations: translations)
        return try await api.request("PUT", "/words/\(id)", jsonBody: body, as: WordOut.self)
    }

    // MARK: - Delete Word
    func deleteWord(id: Int) async throws {
        _ = try await api.request("DELETE", "/words/\(id)", as: Empty.self)
    }
}

