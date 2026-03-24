//
//  VocabularyDataSource.swift
//  LessonClient
//
//  Created by ymj on 10/01/25
//

import Foundation

final class VocabularyDataSource {
    static let shared = VocabularyDataSource()
    private let api = APIClient.shared
    private init() {}

    private func jsonNullable<T>(_ value: T?) -> Any {
        if let value { return value }
        return NSNull()
    }

    // MARK: - Create Vocabulary
    @discardableResult
    func createVocabulary(
        text: String,
        lessonId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        phraseId: Int? = nil,
        exampleExercise: Bool? = nil,
        vocabularyExercise: Bool? = nil,
        isForm: Bool? = nil,
        translations: [VocabularyTranslation]? = nil
    ) async throws -> Vocabulary {
        let body = VocabularyUpdate(
            text: text,
            lessonId: lessonId,
            formId: formId,
            senseId: senseId,
            phraseId: phraseId,
            exampleExercise: exampleExercise,
            vocabularyExercise: vocabularyExercise,
            isForm: isForm,
            translations: translations
        )
        return try await api.request("POST", "admin/vocabularies", jsonBody: body.toDict(), as: Vocabulary.self)
    }

    // MARK: - Fetch Vocabularys
    /// 단어 목록 조회 (서버: GET /words)
    /// - Parameters:
    ///   - level: Lesson.level 정확 일치
    ///   - unit: Lesson.unit 정확 일치
    ///   - lessonId: 특정 레슨에 속한 단어만
    ///   - limit: 1...200 (기본 30)
    ///   - offset: 0 이상 (기본 0)
    func vocabularies(
        level: Int? = nil,
        unit: Int? = nil,
        lessonId: Int? = nil,
        limit: Int = 600,
        offset: Int = 0
    ) async throws -> [Vocabulary] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 600))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let level { query.append(.init(name: "level", value: String(level))) }
        if let unit { query.append(.init(name: "unit", value: String(unit))) }
        if let lessonId { query.append(.init(name: "lesson_id", value: String(lessonId))) }

        return try await api.request(
            "GET",
            "admin/vocabularies",
            query: query,
            as: [Vocabulary].self
        )
    }
    
    func vocabulary(id: Int) async throws -> Vocabulary {
        try await api.request("GET", "admin/vocabularies/\(id)", as: Vocabulary.self)
    }

    // MARK: - Search Vocabularys
    func searchVocabularys(
        q: String? = nil,
        level: Int? = nil,
        unit: Int? = nil,
        limit: Int = 30,
        langs: [String]? = nil
    ) async throws -> [Vocabulary] {
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

        return try await api.request("GET", "admin/vocabularies/search", query: items, as: [Vocabulary].self)
    }
    
    func wordsLessThan(unit: Int) async throws -> [Vocabulary] {
        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "unit_lt",  value: String(unit)))
        return try await api.request("GET", "admin/vocabularies/list/unit-lt", query: items, as: [Vocabulary].self)
    }

    func listUnassigned(
        word: String? = nil,
        limit: Int = 30
    ) async throws -> [Vocabulary] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200)))
        ]
        if let word {
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                query.append(.init(name: "word", value: trimmed))
            }
        }

        return try await api.request(
            "GET",
            "admin/vocabularies/list/unassigned",
            query: query,
            as: [Vocabulary].self
        )
    }

    func listByWord(
        wordId: Int,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> [Vocabulary] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        return try await api.request(
            "GET",
            "admin/vocabularies/by-word/\(wordId)",
            query: query,
            as: [Vocabulary].self
        )
    }

    func listByWordAndCefr(
        wordId: Int,
        cefr: String,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> [Vocabulary] {
        let trimmedCefr = cefr.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: [URLQueryItem] = [
            .init(name: "word_id", value: String(wordId)),
            .init(name: "cefr", value: trimmedCefr.uppercased()),
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        return try await api.request(
            "GET",
            "admin/vocabularies/filter/by-word-cefr",
            query: query,
            as: [Vocabulary].self
        )
    }

    func listByForm(
        formId: Int,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> [Vocabulary] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        return try await api.request(
            "GET",
            "admin/vocabularies/by-form/\(formId)",
            query: query,
            as: [Vocabulary].self
        )
    }

    func listBySense(
        senseId: Int,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> [Vocabulary] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        return try await api.request(
            "GET",
            "admin/vocabularies/by-sense/\(senseId)",
            query: query,
            as: [Vocabulary].self
        )
    }

    func listBySenseForm(
        senseId: Int,
        formId: Int? = nil,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> [Vocabulary] {
        var query: [URLQueryItem] = [
            .init(name: "sense_id", value: String(senseId)),
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let formId {
            query.append(.init(name: "form_id", value: String(formId)))
        }

        return try await api.request(
            "GET",
            "admin/vocabularies/filter/by-sense",
            query: query,
            as: [Vocabulary].self
        )
    }

    // MARK: - Update Vocabulary
    @discardableResult
    func updateVocabulary(
        id: Int,
        text: String? = nil,
        lessonId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        phraseId: Int? = nil,
        exampleExercise: Bool? = nil,
        vocabularyExercise: Bool? = nil,
        isForm: Bool? = nil,
        translations: [VocabularyTranslation]? = nil
    ) async throws -> Vocabulary {
        let body = VocabularyUpdate(
            text: text,
            lessonId: lessonId,
            formId: formId,
            senseId: senseId,
            phraseId: phraseId,
            exampleExercise: exampleExercise,
            vocabularyExercise: vocabularyExercise,
            isForm: isForm,
            translations: translations
        )
        return try await api.request("PUT", "admin/vocabularies/\(id)", jsonBody: body.toDict(), as: Vocabulary.self)
    }

    /// Replace vocabulary fields with nullable payload (`null` 포함 PUT).
    /// 검사 결과 expected 값을 그대로 반영할 때 사용합니다.
    @discardableResult
    func replaceVocabulary(
        id: Int,
        text: String,
        lessonId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        phraseId: Int? = nil,
        exampleExercise: Bool,
        vocabularyExercise: Bool,
        isForm: Bool,
        translations: [VocabularyTranslation]? = nil
    ) async throws -> Vocabulary {
        let body: [String: Any] = [
            "text": text,
            "lesson_id": jsonNullable(lessonId),
            "form_id": jsonNullable(formId),
            "sense_id": jsonNullable(senseId),
            "phrase_id": jsonNullable(phraseId),
            "example_exercise": exampleExercise,
            "vocabulary_exercise": vocabularyExercise,
            "is_form": isForm,
            "translations": translations?.toArray() ?? []
        ]
        return try await api.request(
            "PUT",
            "admin/vocabularies/\(id)",
            jsonBody: body,
            as: Vocabulary.self
        )
    }

    // MARK: - Delete Vocabulary
    func deleteVocabulary(id: Int) async throws {
        _ = try await api.request("DELETE", "admin/vocabularies/\(id)", as: Empty.self)
    }
}
