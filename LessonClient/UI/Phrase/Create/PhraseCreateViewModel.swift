//
//  PhraseCreateViewModel.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import Foundation

@MainActor
final class PhraseCreateViewModel: ObservableObject {
    @Published var rawText: String = ""
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createPhrases() async throws -> [PhraseRead] {
        guard canSubmit else {
            throw NSError(
                domain: "invalid.form",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "입력을 확인해 주세요."]
            )
        }
        isSaving = true
        defer { isSaving = false }

        let blocks = parseBlocks(rawText)
        if blocks.isEmpty {
            throw NSError(
                domain: "invalid.form",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "파싱 가능한 phrase 블록이 없습니다."]
            )
        }

        var created: [PhraseRead] = []
        created.reserveCapacity(blocks.count)
        var failures: [String] = []

        for (index, block) in blocks.enumerated() {
            do {
                let phrase = try await PhraseDataSource.shared.createPhrase(
                    text: block.phrase,
                    lessonTargetId: nil,
                    translations: block.translations.isEmpty ? nil : block.translations
                )
                created.append(phrase)
            } catch {
                failures.append("#\(index + 1): \(error.localizedDescription)")
                continue
            }
        }

        if created.isEmpty {
            let message = failures.isEmpty
                ? "생성된 phrase가 없습니다."
                : "모든 phrase 생성에 실패했습니다.\n" + failures.joined(separator: "\n")
            throw NSError(
                domain: "phrase.create.failed",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        if !failures.isEmpty {
            errorMessage = "일부 phrase 생성 실패:\n" + failures.joined(separator: "\n")
        }

        return created
    }

    private func parseBlocks(_ raw: String) -> [(phrase: String, translations: [PhraseTranslationSchema])] {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let blocks = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return blocks.compactMap { block in
            let lines = block
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var phraseText: String?
            var translations: [PhraseTranslationSchema] = []

            for line in lines {
                guard let colonIdx = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { continue }

                if key.lowercased() == "phrase" {
                    phraseText = value
                } else {
                    translations.append(PhraseTranslationSchema(lang: key, text: value))
                }
            }

            guard let phraseText, !phraseText.isEmpty else { return nil }
            return (phrase: phraseText, translations: translations)
        }
    }
}
