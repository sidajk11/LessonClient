//
//  WordDetailViewModel.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import Foundation

@MainActor
final class WordDetailViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var word: WordRead?
    @Published private(set) var senses: [WordSenseRead] = []
    @Published var senseCellList: [WordViewData.Sense] = []

    let wordId: Int
    private let dataSource: WordDataSource

    // 전체 삭제용
    @Published var showDeleteAllConfirm: Bool = false
    @Published var isDeletingAll: Bool = false

    // 번역 추가용
    @Published var showAddTranslationsSheet: Bool = false
    @Published var addTranslationsText: String = ""
    @Published var isAddingTranslations: Bool = false

    init(wordId: Int, dataSource: WordDataSource = .shared) {
        self.wordId = wordId
        self.dataSource = dataSource
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let word = try await dataSource.word(id: wordId)
            self.word = word
            self.senses = word.senses
            senseCellList = senses.map { sense in
                WordViewData.Sense(
                    senseCode: sense.senseCode,
                    tr1: sense.translations.first?.text ?? "",
                    tr2: sense.translations.first(where: { $0.lang == "ja" })?.text ?? "",
                    pos: sense.pos?.uppercased() ?? "",
                    explain: sense.translations.first(where: { $0.lang == "ko" })?.explain ?? ""
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteAllSenses() async {
        guard !isDeletingAll else { return }
        guard !senses.isEmpty else { return }

        isDeletingAll = true
        errorMessage = nil
        defer { isDeletingAll = false }

        let toDelete = senses

        do {
            for sense in toDelete {
                try await dataSource.deleteWordSense(senseId: sense.id)
                senses.removeAll { $0.id == sense.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 입력된 블록들을 sense 순서대로 번역 추가
    /// - Returns: 성공 여부 (sheet 닫을지 판단용)
    func addTranslationsToSenses() async -> Bool {
        guard !isAddingTranslations else { return false }
        guard !senses.isEmpty else {
            errorMessage = "No senses to add translations."
            return false
        }

        isAddingTranslations = true
        errorMessage = nil
        defer { isAddingTranslations = false }

        let parsed = Self.parseNewFormat(addTranslationsText)

        if parsed.blocks.isEmpty {
            errorMessage = "입력에서 블록을 찾지 못했습니다. '---'로 블록을 구분해 주세요."
            return false
        }

        let count = min(parsed.blocks.count, senses.count)

        do {
            for i in 0..<count {
                let senseId = senses[i].id
                let block = parsed.blocks[i]

                // sense_en (없으면 빈문자)
                let fallbackExplain = block.senseExplain ?? ""

                // ko/es/... 번역들을 sense에 추가/업데이트
                for (lang, text) in block.headTranslations {
                    // explain은 sense_<lang> 우선, 없으면 sense_en
                    let explainForLang = block.senseExplainTranslations[lang] ?? fallbackExplain

                    let updatedSense = try await dataSource.updateSenseTranslation(
                        senseId: senseId,
                        lang: lang,
                        text: text,
                        explain: explainForLang
                    )

                    // 서버 응답을 바로 반영하고 싶으면(선택)
                    if let idx = senses.firstIndex(where: { $0.id == senseId }) {
                        senses[idx] = updatedSense
                    }
                }
            }

            // 전체 싱크 맞추고 싶으면(권장)
            await load()
            addTranslationsText = ""
            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }


}

// MARK: - Parsing

extension WordDetailViewModel {
    struct ParsedSenseBlock {
        var senseExplain: String?                 // from sense_en
        var senseExplainTranslations: [String: String] = [:] // from sense_ko, sense_es...
        var headTranslations: [String: String] = [:]         // from ko, es...
    }

    struct ParsedInput {
        var word: String?
        var blocks: [ParsedSenseBlock] = []
    }

    static func parseNewFormat(_ input: String) -> ParsedInput {
        let normalized = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // --- 기준으로 블록 분리
        let parts = normalized
            .components(separatedBy: "\n---\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var parsed = ParsedInput(word: nil, blocks: [])

        for (idx, part) in parts.enumerated() {
            let lines = part
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // 첫 블록에 word: 가 들어올 수 있음
            if idx == 0 {
                for line in lines {
                    guard let colon = line.firstIndex(of: ":") else { continue }
                    let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if key.lowercased() == "word", !value.isEmpty {
                        parsed.word = value
                        break
                    }
                }
            }

            var block = ParsedSenseBlock()

            for line in lines {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let keyRaw = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !keyRaw.isEmpty, !value.isEmpty else { continue }

                let key = keyRaw.trimmingCharacters(in: .whitespacesAndNewlines)

                if key.lowercased() == "word" {
                    // 블록 내부 word: 는 무시(전체 word만 사용)
                    continue
                }

                if key.lowercased().hasPrefix("sense_") {
                    // sense_en / sense_ko / sense_zh-CN ...
                    let lang = String(key.dropFirst("sense_".count)) // keep case like zh-CN
                    if lang.lowercased() == "en" {
                        block.senseExplain = value // ✅ explain
                    } else {
                        block.senseExplainTranslations[lang] = value
                    }
                } else {
                    // ko / es / fr ...
                    block.headTranslations[key] = value
                }
            }

            // 유효 블록 판단: explain 또는 headTranslations 중 하나라도 있으면 포함
            if block.senseExplain != nil || !block.headTranslations.isEmpty || !block.senseExplainTranslations.isEmpty {
                parsed.blocks.append(block)
            }
        }

        return parsed
    }
}

extension WordDetailViewModel {
    func formattedCopyText() -> String {
        guard let word else { return "" }
        let text = word.toSenseBulkText()
        return text
    }
}

