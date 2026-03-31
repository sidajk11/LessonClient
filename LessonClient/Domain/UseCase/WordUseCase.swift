//
//  WordUseCase.swift
//  LessonClient
//
//  Created by ym on 3/18/26.
//

import Foundation

// 단어, 구문, 활용형, vocabulary 조회를 한 곳에서 조합해 제공합니다.
class WordUseCase {
    static let shared = WordUseCase()

    private let wordDataSource = WordDataSource.shared
    private let phraseDataSource = PhraseDataSource.shared
    private let formDataSource = WordFormDataSource.shared
    private let vocabularyDataSource = VocabularyDataSource.shared

    func findWord(byEnglish text: String) async throws -> WordRead? {
        let query = try validatedQuery(from: text)

        do {
            return try await wordDataSource.getWord(word: query)
        } catch {
            guard isNotFound(error) else { throw error }
        }
        return nil
    }

    func findPhrase(byEnglish text: String) async throws -> PhraseRead? {
        let query = try validatedQuery(from: text)
        let rows = try await phraseDataSource.listPhrases(q: query, limit: 20, offset: 0)

        return rows.first { matches($0.text, query: query) }
    }

    func findForm(byEnglish text: String) async throws -> WordFormRead? {
        let query = try validatedQuery(from: text)
        let rows = try await formDataSource.listWordFormsByForm(form: query, limit: 20, offset: 0)

        return rows.first { matches($0.form, query: query) }
    }

    func findVocabulary(byEnglish text: String) async throws -> [Vocabulary] {
        let query = try validatedQuery(from: text)
        let rows = try await vocabularyDataSource.searchVocabularys(q: query, limit: 20)
        let filtered = rows.filter { matches($0.text, query: query) }
        if !filtered.isEmpty {
            return filtered
        }

        guard let form = try await findForm(byEnglish: query) else {
            return []
        }

        return try await findVocabulary(formId: form.id)
    }

    func findVocabulary(senseId: Int, formId: Int?) async throws -> [Vocabulary] {
        try await vocabularyDataSource.listBySenseForm(senseId: senseId, formId: formId, limit: 20, offset: 0)
    }

    func findVocabulary(formId: Int) async throws -> [Vocabulary] {
        try await vocabularyDataSource.listByForm(formId: formId, limit: 20, offset: 0)
    }

    func findVocabulary(phraseId: Int) async throws -> [Vocabulary] {
        let phrase = try await phraseDataSource.phrase(id: phraseId)
        return try await findVocabulary(byEnglish: phrase.text)
    }

    func findVocabulary(wordId: Int) async throws -> [Vocabulary] {
        try await vocabularyDataSource.listByWord(wordId: wordId, limit: 20, offset: 0)
    }

    private func validatedQuery(from text: String) throws -> String {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw NSError(
                domain: "WordUseCase",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "조회할 영어 단어가 비어 있습니다."]
            )
        }
        return query
    }

    private func matches(_ value: String, query: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private func isNotFound(_ error: Error) -> Bool {
        if case APIClient.APIError.http(let statusCode, _) = error {
            return statusCode == 404
        }
        return false
    }
}
