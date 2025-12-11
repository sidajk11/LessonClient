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
    func createWord(text: String, lessonId: Int? = nil, translations: [WordTranslation]? = nil) async throws -> Word {
        let body = WordUpdate(text: text, lessonId: lessonId, translations: translations)
        return try await api.request("POST", "admin/words", jsonBody: body, as: Word.self)
    }

    // MARK: - Fetch Words
    /// 단어 목록 조회 (서버: GET /words)
    /// - Parameters:
    ///   - level: Lesson.level 정확 일치
    ///   - unit: Lesson.unit 정확 일치
    ///   - lessonId: 특정 레슨에 속한 단어만
    ///   - limit: 1...200 (기본 30)
    ///   - offset: 0 이상 (기본 0)
    func words(
        level: Int? = nil,
        unit: Int? = nil,
        lessonId: Int? = nil,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> [Word] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let level { query.append(.init(name: "level", value: String(level))) }
        if let unit { query.append(.init(name: "unit", value: String(unit))) }
        if let lessonId { query.append(.init(name: "lesson_id", value: String(lessonId))) }

        return try await api.request(
            "GET",
            "admin/words",
            query: query,
            as: [Word].self
        )
    }
    
    func word(id: Int, lang: String = "ko") async throws -> Word {
        try await api.request("GET", "admin/words/\(id)", as: Word.self)
    }

    // MARK: - Search Words
    func searchWords(
        q: String? = nil,
        level: Int? = nil,
        unit: Int? = nil,
        limit: Int = 30,
        langs: [String]? = nil
    ) async throws -> [Word] {
        var items: [URLQueryItem] = []
        // 서버 기본값이 "" 이므로 nil이어도 q 파라미터는 넣어줍니다.
        if let q {
            let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(URLQueryItem(name: "q", value: trimmed))
        }
        items.append(URLQueryItem(name: "limit", value: String(limit)))

        if let level { items.append(URLQueryItem(name: "level", value: String(level))) }
        if let unit  { items.append(URLQueryItem(name: "unit",  value: String(unit))) }

        if let langs, !langs.isEmpty {
            // 서버는 comma-separated 수신: "ko,en"
            items.append(URLQueryItem(name: "langs", value: langs.joined(separator: ",")))
        }

        return try await api.request("GET", "admin/words/search", query: items, as: [Word].self)
    }
    
    func wordsLessThan(unit: Int) async throws -> [Word] {
        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "unit_lt",  value: String(unit)))
        return try await api.request("GET", "admin/words/list/unit-lt", query: items, as: [Word].self)
    }

    func listUnassigned() async throws -> [Word] {
        return try await api.request("GET", "admin/words/list/unassigned", as: [Word].self)
    }

    // MARK: - Update Word
    @discardableResult
    func updateWord(id: Int, text: String? = nil, lessonId: Int? = nil, translations: [WordTranslation]? = nil) async throws -> Word {
        let body = WordUpdate(text: text, lessonId: lessonId, translations: translations)
        return try await api.request("PUT", "admin/words/\(id)", jsonBody: body, as: Word.self)
    }

    // MARK: - Delete Word
    func deleteWord(id: Int) async throws {
        _ = try await api.request("DELETE", "admin/words/\(id)", as: Empty.self)
    }
}
