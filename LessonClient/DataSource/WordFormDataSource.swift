//
//  WordFormDataSource.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import Foundation

final class WordFormDataSource {
    static let shared = WordFormDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - form 문자열로 WordForm 조회 (GET /word-forms/by-form)
    func listWordFormsByForm(
        form: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [WordFormRead] {
        let trimmed = form.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: [URLQueryItem] = [
            .init(name: "form", value: trimmed),
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        return try await api.request(
            "GET",
            "admin/word-forms/by-form",
            query: query,
            as: [WordFormRead].self
        )
    }

    // MARK: - word_id로 WordForm 조회 (GET /word-forms/by-word/{word_id})
    func listWordFormsByWord(
        wordId: Int,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [WordFormRead] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        return try await api.request(
            "GET",
            "admin/word-forms/by-word/\(wordId)",
            query: query,
            as: [WordFormRead].self
        )
    }

    // MARK: - WordForm 목록 조회 (GET /word-forms)
    func listWordForms(
        wordId: Int? = nil,
        formType: String? = nil,
        q: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [WordFormRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        if let wordId { query.append(.init(name: "word_id", value: String(wordId))) }

        if let formType, !formType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(.init(
                name: "form_type",
                value: formType.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        if let q, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(.init(
                name: "q",
                value: q.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        return try await api.request(
            "GET",
            "admin/word-forms",
            query: query,
            as: [WordFormRead].self
        )
    }

    // MARK: - WordForm 생성 (POST /word-forms)
    @discardableResult
    func createWordForm(
        wordId: Int,
        derivedWordId: Int? = nil,
        form: String,
        formType: String? = nil,
        translations: [WordFormTranslationSchema]? = nil
    ) async throws -> WordFormRead {
        let body = WordFormCreate(
            wordId: wordId,
            derivedWordId: derivedWordId,
            form: form,
            formType: formType,
            translations: translations
        )

        return try await api.request(
            "POST",
            "admin/word-forms",
            jsonBody: body.toDict(),
            as: WordFormRead.self
        )
    }

    // MARK: - WordForm 단건 조회 (GET /word-forms/{form_id})
    func wordForm(id formId: Int) async throws -> WordFormRead {
        try await api.request(
            "GET",
            "admin/word-forms/\(formId)",
            as: WordFormRead.self
        )
    }

    // MARK: - WordForm 수정 (PUT /word-forms/{form_id})
    @discardableResult
    func updateWordForm(
        id formId: Int,
        wordId: Int? = nil,
        form: String? = nil,
        formType: String? = nil,
        translations: [WordFormTranslationSchema]? = nil
    ) async throws -> WordFormRead {
        let body = WordFormUpdate(
            wordId: wordId,
            form: form,
            formType: formType,
            translations: translations
        )

        return try await api.request(
            "PUT",
            "admin/word-forms/\(formId)",
            jsonBody: body.toDict(),
            as: WordFormRead.self
        )
    }

    // MARK: - WordForm 삭제 (DELETE /word-forms/{form_id})
    func deleteWordForm(id formId: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/word-forms/\(formId)",
            as: Empty.self
        )
    }
}
