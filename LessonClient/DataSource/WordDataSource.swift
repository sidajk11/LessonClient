//
//  WordDataSource.swift
//  LessonClient
//
//  Created by ym on 2/12/26.
//

import Foundation

final class WordDataSource {
    static let shared = WordDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Word 조회 (GET /words/{word_id})
    func word(id: Int) async throws -> WordRead {
        try await api.request(
            "GET",
            "admin/words/\(id)",
            as: WordRead.self
        )
    }

    // MARK: - Word 생성 (POST /words)
    @discardableResult
    func createWord(
        lemma: String,
        kind: String = "WORD"
    ) async throws -> WordRead {
        let body = WordUpdate(lemma: lemma, kind: kind)
        return try await api.request(
            "POST",
            "admin/words",
            jsonBody: body.toDict(),
            as: WordRead.self
        )
    }

    // MARK: - Word 수정 (PUT /words/{word_id})
    @discardableResult
    func updateWord(
        id: Int,
        lemma: String? = nil,
        kind: String? = nil
    ) async throws -> WordRead {
        let body = WordUpdate(lemma: lemma, kind: kind)
        return try await api.request(
            "PUT",
            "admin/words/\(id)",
            jsonBody: body.toDict(),
            as: WordRead.self
        )
    }

    // MARK: - WordSense 목록 조회 (GET /words/{word_id}/senses)
    func listWordSenses(
        wordId: Int,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [WordSenseRead] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        return try await api.request(
            "GET",
            "admin/words/\(wordId)/senses",
            query: query,
            as: [WordSenseRead].self
        )
    }

    // MARK: - WordSense 단건 조회 (GET /words/senses/{sense_id})
    func wordSense(senseId: Int) async throws -> WordSenseRead {
        try await api.request(
            "GET",
            "admin/words/senses/\(senseId)",
            as: WordSenseRead.self
        )
    }

    // MARK: - WordSense 생성 (POST /words/{word_id}/senses)
    @discardableResult
    func createWordSense(
        wordId: Int,
        senseCode: String,
        explain: String,
        pos: String?,
        cefr: String?,
        translations: [WordSenseTranslation]? = nil
    ) async throws -> WordSenseRead {
        let body = WordSenseCreate(
            senseCode: senseCode,
            explain: explain,
            pos: pos,
            cefr: cefr,
            translations: translations
        )
        return try await api.request(
            "POST",
            "admin/words/\(wordId)/senses",
            jsonBody: body.toDict(),
            as: WordSenseRead.self
        )
    }

    // MARK: - WordSense 수정 (PUT /words/senses/{sense_id})
    @discardableResult
    func updateWordSense(
        senseId: Int,
        senseCode: String? = nil,
        explain: String? = nil,
        pos: String? = nil,
        cefr: String? = nil,
        translations: [WordSenseTranslation]? = nil
    ) async throws -> WordSenseRead {
        let body = WordSenseUpdate(
            senseCode: senseCode,
            explain: explain,
            pos: pos,
            cefr: cefr,
            translations: translations
        )
        return try await api.request(
            "PUT",
            "admin/words/senses/\(senseId)",
            jsonBody: body.toDict(),
            as: WordSenseRead.self
        )
    }

    // MARK: - WordSense 삭제 (DELETE /words/senses/{sense_id})
    func deleteWordSense(senseId: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/words/senses/\(senseId)",
            as: Empty.self
        )
    }

    // MARK: - Word 삭제 (DELETE /words/{word_id})
    func deleteWord(id: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/words/\(id)",
            as: Empty.self
        )
    }
    
    // MARK: - WordSense 예문 연결 (POST /words/senses/{sense_id}/examples)
    @discardableResult
    func attachExampleToWordSense(
        senseId: Int,
        exampleId: Int,
        isPrime: Bool = false
    ) async throws -> WordSenseExampleRead {
        struct AttachBody: Encodable {
            let example_id: Int
            let is_prime: Bool
        }
        let body = AttachBody(example_id: exampleId, is_prime: isPrime)
        return try await api.request(
            "POST",
            "admin/words/senses/\(senseId)/examples",
            jsonBody: body.toDict(),
            as: WordSenseExampleRead.self
        )
    }
    
    @discardableResult
    func updateSenseTranslation(senseId: Int, lang: String, text: String, explain: String) async throws -> WordSenseRead {
        // PUT /words/senses/{sense_id}/translations
        // body: { "lang": lang, "text": text, "explain": "" }
        struct Body: Encodable {
            let lang: String
            let text: String
            let explain: String
        }
        let body = Body(lang: lang, text: text, explain: explain)
        return try await api.request(
            "PUT",
            "admin/words/senses/\(senseId)/translations",
            jsonBody: body.toDict(),
            as: WordSenseRead.self
        )
    }
}

extension WordDataSource {
    /// 단어 목록 조회 (서버: GET /words)
    func listWords(
        q: String? = nil,
        kind: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [WordRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let q, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(.init(name: "q", value: q.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if let kind, !kind.isEmpty { query.append(.init(name: "kind", value: kind)) }

        return try await api.request("GET", "admin/words", query: query, as: [WordRead].self)
    }

    /// 폼이 없는 단어 목록 조회 (서버: GET /words/no-forms)
    func listWordsWithoutForms(
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [WordRead] {
        let query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        return try await api.request(
            "GET",
            "admin/words/no-forms",
            query: query,
            as: [WordRead].self
        )
    }
    
    /// 단어 텍스트로 단건 조회 (서버: GET /words/search?word=...)
    func findWord(word: String) async throws -> WordRead {
        let query: [URLQueryItem] = [
            .init(name: "word", value: word)
        ]
        return try await api.request(
            "GET",
            "admin/words/search",
            query: query,
            as: WordRead.self
        )
    }
    
    func getWord(word: String) async throws -> WordRead {
        let query: [URLQueryItem] = [
            .init(name: "lemma", value: word)
        ]
        return try await api.request(
            "GET",
            "admin/words/by-lemma",
            query: query,
            as: WordRead.self
        )
    }

    /// lemma로 sense 목록 조회 (서버: GET /words/senses/by-lemma?lemma=...)
    func listWordSensesByLemma(
        lemma: String,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [WordSenseRead] {
        try await listWordSensesByLemma(
            path: "admin/words/senses/by-lemma",
            lemma: lemma,
            cefr: nil,
            limit: limit,
            offset: offset
        )
    }

    /// lemma + CEFR로 sense 목록 조회 (서버: GET /words/senses/by-lemma-cefr?lemma=...&cefr=...)
    func listWordSensesByLemmaAndCefr(
        lemma: String,
        cefr: String,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [WordSenseRead] {
        try await listWordSensesByLemma(
            path: "admin/words/senses/by-lemma-cefr",
            lemma: lemma,
            cefr: cefr,
            limit: limit,
            offset: offset
        )
    }

    private func listWordSensesByLemma(
        path: String,
        lemma: String,
        cefr: String?,
        limit: Int,
        offset: Int
    ) async throws -> [WordSenseRead] {
        let trimmed = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCefr = cefr?.trimmingCharacters(in: .whitespacesAndNewlines)
        var query: [URLQueryItem] = [
            .init(name: "lemma", value: trimmed),
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]
        if let trimmedCefr, !trimmedCefr.isEmpty {
            query.append(.init(name: "cefr", value: trimmedCefr.uppercased()))
        }
        return try await api.request(
            "GET",
            path,
            query: query,
            as: [WordSenseRead].self
        )
    }
}
