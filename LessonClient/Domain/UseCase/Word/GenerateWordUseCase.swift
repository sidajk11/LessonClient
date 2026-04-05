//
//  GenerateWordUseCase.swift
//  LessonClient
//
//  Created by Codex on 4/5/26.
//

import Foundation

// surface에서 lemma를 뽑아 word를 만들고 필요한 form까지 함께 생성합니다.
@MainActor
final class GenerateWordUseCase {
    struct Result {
        let word: WordRead
        let wordWasCreated: Bool
    }

    static let shared = GenerateWordUseCase()

    private let wordUseCase = WordUseCase.shared
    private let wordDataSource = WordDataSource.shared
    private let formDataSource = WordFormDataSource.shared
    private let openAIClient = OpenAIClient()

    private enum GenerateWordError: LocalizedError {
        case emptySurface
        case noLemma(String)

        var errorDescription: String? {
            switch self {
            case .emptySurface:
                return "생성할 단어가 비어 있습니다."
            case .noLemma(let raw):
                return "lemma를 추출하지 못했습니다: \(raw)"
            }
        }
    }

    private init() {}

    // surface를 lemma로 정규화한 뒤 word와 form이 모두 준비되도록 보장합니다.
    func ensureWord(surface rawSurface: String) async throws -> Result {
        let surface = rawSurface.trimmed
        guard !surface.isEmpty else {
            throw GenerateWordError.emptySurface
        }

        let lemma = try await lemma(from: surface)

        if let existingWord = try await wordUseCase.findWord(byEnglish: lemma) {
            if try await shouldGenerateForms(for: existingWord) {
                _ = try await AutoGenerateWordSensesUseCase.shared.generateForms(for: lemma, word: existingWord)
            }
            return Result(word: existingWord, wordWasCreated: false)
        }

        let created = try await wordDataSource.createWord(lemma: lemma)
        _ = try await AutoGenerateWordSensesUseCase.shared.generateForms(for: lemma, word: created)
        return Result(word: created, wordWasCreated: true)
    }

    private func shouldGenerateForms(for word: WordRead) async throws -> Bool {
        let existingForms = try await formDataSource.listWordForms(wordId: word.id, limit: 1, offset: 0)
        return existingForms.isEmpty
    }

    private func lemma(from surface: String) async throws -> String {
        let generated = try await openAIClient.generateText(
            prompt: Prompt.makeLemmaPrompt(for: surface)
        )
        let tokens = generated
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))

        for token in tokens {
            let lemma = sanitizeLemmaToken(token)
            if !lemma.isEmpty {
                return lemma
            }
        }

        throw GenerateWordError.noLemma(generated.trimmed.isEmpty ? surface : generated)
    }

    private func sanitizeLemmaToken(_ token: String) -> String {
        var value = token.trimmed
        guard !value.isEmpty else { return "" }

        if let colonIndex = value.firstIndex(of: ":") {
            let key = value[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if key == "lemma" || key == "lemmas" || key == "word" || key == "words" {
                value = String(value[value.index(after: colonIndex)...]).trimmed
            }
        }

        value = value.trimmingCharacters(
            in: CharacterSet(charactersIn: "\"'`[](){}.-•0123456789 ").union(.whitespacesAndNewlines)
        )
        return value
    }
}
