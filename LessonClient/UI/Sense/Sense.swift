//
//  Sense.swift
//  LessonClient
//
//  Created by ym on 2/12/26.
//

import Foundation

enum SenseBulkParser {
    struct Item: Hashable {
        var sense: String
        var pos: String
        var cefr: String
        var ko: String
        var example: String
    }

    struct Parsed {
        var head: String
        var items: [Item]
    }

    enum ParseError: LocalizedError {
        case empty
        case missingWord
        case noItems
        case invalidBlock(String)

        var errorDescription: String? {
            switch self {
            case .empty: return "입력값이 비어있어요."
            case .missingWord: return "`word:`를 찾지 못했어요. (예: word: phone)"
            case .noItems: return "sense 블록을 찾지 못했어요."
            case .invalidBlock(let msg): return "블록 파싱 실패: \(msg)"
            }
        }
    }

    static func parse(_ raw: String) throws -> Parsed {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }

        // 빈 줄 기준 블록 분리
        let blocks = splitIntoBlocks(trimmed)

        var head: String?
        var items: [Item] = []

        for block in blocks {
            let t = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }

            guard let (word, item) = parseBlockWithWord(t) else {
                throw ParseError.invalidBlock(block)
            }

            if head == nil { head = word }
            // 필요하면 여기서 word 불일치 검사 가능:
            // if let h = head, h != word { throw ParseError.invalidBlock("word 불일치: \(h) vs \(word)\n\n\(block)") }

            items.append(item)
        }

        guard let head else { throw ParseError.missingWord }
        guard !items.isEmpty else { throw ParseError.noItems }

        return Parsed(head: head, items: items)
    }

    private static func parseBlockWithWord(_ block: String) -> (word: String, item: Item)? {
        var word: String?
        var sense: String?
        var pos: String?
        var cefr: String?
        var ko: String?
        var example: String?

        let lines = block
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            guard let idx = line.firstIndex(of: ":") else { continue }
            let key = line[..<idx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)

            switch key {
            case "word": word = value
            case "sense": sense = value
            case "pos": pos = value
            case "cefr": cefr = value
            case "ko": ko = value
            case "example": example = value
            default: break
            }
        }

        guard
            let word, !word.isEmpty,
            let sense, !sense.isEmpty,
            let pos, !pos.isEmpty,
            let cefr, !cefr.isEmpty,
            let ko, !ko.isEmpty
        else { return nil }

        return (
            word,
            Item(
                sense: sense,
                pos: pos,
                cefr: cefr,
                ko: ko,
                example: example ?? ""
            )
        )
    }

    private static func splitIntoBlocks(_ s: String) -> [String] {
        // 빈 줄(연속 개행) 기준으로 블록 분리
        let normalized = s.replacingOccurrences(of: "\r\n", with: "\n")
        var blocks: [String] = []
        var current: [String] = []

        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let str = String(line)
            if str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty {
                    blocks.append(current.joined(separator: "\n"))
                    current.removeAll()
                }
            } else {
                current.append(str)
            }
        }
        if !current.isEmpty {
            blocks.append(current.joined(separator: "\n"))
        }
        return blocks
    }
}
