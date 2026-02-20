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

    private static func parseBlockWithWord(_ block: String) -> (word: String?, item: Item)? {
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
            var value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
            value = value.replacingOccurrences(of: "’", with: "'")

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

// MARK: - WordRead -> Bulk text (SenseBulkParser input format)
extension WordRead {

    /// WordRead 모델을 SenseBulkParser가 읽을 수 있는 "bulk text" 포맷으로 변환합니다.
    ///
    /// - Parameters:
    ///   - koLang: translations에서 한국어를 찾을 때 사용할 lang 값 (기본 "ko")
    ///   - cefrProvider: 각 sense의 CEFR 값을 제공 (기본: senseCode가 CEFR처럼 보이면 사용, 아니면 "-")
    ///   - koProvider: 각 sense의 한국어(ko) 값을 제공 (기본: translations에서 koLang 매칭되는 text)
    ///   - exampleProvider: 각 sense의 example 문장을 제공 (기본: nil -> 빈 문자열)
    ///
    /// - Returns: SenseBulkParser 입력 포맷 문자열
    func toSenseBulkText(
        koLang: String = "ko"
    ) -> String {
        let koProvider: (WordSenseRead) -> String? = { sense in
            sense.translations.first(where: { $0.lang.lowercased() == koLang.lowercased() })?.text
        }
        
        let wordLine = "word: \(lemma)"

        // senses가 비어있으면 word만 출력하거나 빈 문자열로 할지 선택 가능
        guard !senses.isEmpty else { return wordLine }

        var blocks: [String] = []
        blocks.reserveCapacity(senses.count)

        for (idx, s) in senses.enumerated() {
            let senseText = s.explain.trimmingCharacters(in: .whitespacesAndNewlines)
            let posText = (s.pos ?? "-").trimmingCharacters(in: .whitespacesAndNewlines)
            let cefrText = (s.cefr ?? "-").trimmingCharacters(in: .whitespacesAndNewlines)
            let koText = (koProvider(s) ?? "-").trimmingCharacters(in: .whitespacesAndNewlines)
            let exText = (s.examples.first?.sentence ?? "-").trimmingCharacters(in: .whitespacesAndNewlines)

            // SenseBulkParser는 블록마다 word가 "있어도 되고 없어도" 되지만,
            // 예시 포맷처럼 첫 블록에만 word를 넣어줍니다.
            var lines: [String] = []
            if idx == 0 { lines.append(wordLine) }

            lines.append("sense: \(senseText.isEmpty ? "-" : senseText)")
            lines.append("pos: \(posText.isEmpty ? "-" : posText)")
            lines.append("cefr: \(cefrText.isEmpty ? "-" : cefrText)")
            lines.append("ko: \(koText.isEmpty ? "-" : koText)")
            lines.append("example: \(exText)") // example은 비어도 OK (파서는 example optional)

            blocks.append(lines.joined(separator: "\n"))
        }

        // 블록 간 빈 줄 1개 (예시 포맷)
        return blocks.joined(separator: "\n\n")
    }

    private static func isCefrLike(_ s: String) -> Bool {
        // A1, A2, B1, B2, C1, C2 형태만 true
        let upper = s.uppercased()
        return upper == "A1" || upper == "A2" || upper == "B1" || upper == "B2" || upper == "C1" || upper == "C2"
    }
}

