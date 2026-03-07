//
//  FormBlocksParser.swift
//  LessonClient
//
//  Created by ym on 3/2/26.
//

import Foundation

final class FormBlocksParser {
    struct ParseResult {
        let rows: [FormCreateViewModel.DraftRow]
        let totalBlocks: Int
        let skippedBlocks: Int
    }

    func parse(rawText: String) -> ParseResult {
        let blocks = splitIntoBlocks(rawText)
        let totalBlocks = blocks.count

        var parsed: [FormCreateViewModel.DraftRow] = []
        var skippedBlocks = 0

        for block in blocks {
            if let row = parseBlock(block) {
                let word = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
                let form = row.form.trimmingCharacters(in: .whitespacesAndNewlines)

                var draft = row
                if word.isEmpty || form.isEmpty {
                    draft.status = .failed(message: "word/form is required")
                } else {
                    draft.status = .ready
                }
                parsed.append(draft)
            } else {
                skippedBlocks += 1
            }
        }

        return ParseResult(
            rows: parsed,
            totalBlocks: totalBlocks,
            skippedBlocks: skippedBlocks
        )
    }

    private func splitIntoBlocks(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let parts = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts.flatMap { part in
            part
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private func parseBlock(_ block: String) -> FormCreateViewModel.DraftRow? {
        var dict: [String: String] = [:]

        let lines = block
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in lines {
            if line.isEmpty { continue }
            guard let idx = line.firstIndex(of: ":") else { continue }

            let key = line[..<idx]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let value = line[line.index(after: idx)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !key.isEmpty { dict[key] = value }
        }

        guard let word = dict["word"], let form = dict["form"] else { return nil }

        let formType = dict["form_type"]
        let explainKo = dict["explain_ko"]

        return FormCreateViewModel.DraftRow(
            word: word,
            form: form,
            formType: (formType?.isEmpty == true ? nil : formType),
            explainKo: (explainKo?.isEmpty == true ? nil : explainKo),
            status: .ready
        )
    }
}
