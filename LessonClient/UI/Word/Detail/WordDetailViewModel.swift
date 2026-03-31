//
//  WordDetailViewModel.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import Foundation
import SwiftUI

@MainActor
final class WordDetailViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var word: WordRead?
    @Published private(set) var senses: [WordSenseRead] = []
    @Published var senseCellList: [WordViewData.Sense] = []
    @Published var posTextBySenseId: [Int: String] = [:]
    @Published private(set) var savingSenseIds: Set<Int> = []

    let wordId: Int
    private let dataSource: WordDataSource

    // 전체 삭제용
    @Published var showDeleteAllConfirm: Bool = false
    @Published var isDeletingAll: Bool = false

    // 번역 추가용
    @Published var showAddTranslationsSheet: Bool = false
    @Published var addTranslationsText: String = ""
    @Published var isAddingTranslations: Bool = false

    // sense 추가용
    @Published var showAddSenseSheet: Bool = false
    @Published var addSenseText: String = ""
    @Published var isAddingSense: Bool = false

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
            apply(word: word)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func posText(for senseId: Int) -> String {
        posTextBySenseId[senseId] ?? ""
    }

    func setPosText(_ text: String, for senseId: Int) {
        posTextBySenseId[senseId] = text
    }

    func isSavingPos(for senseId: Int) -> Bool {
        savingSenseIds.contains(senseId)
    }

    func canSavePos(for senseId: Int) -> Bool {
        guard let sense = senses.first(where: { $0.id == senseId }) else { return false }
        guard !isSavingPos(for: senseId) else { return false }

        let draft = posText(for: senseId).trimmed
        let current = sense.pos?.trimmed ?? ""
        return draft != current
    }

    func savePos(for senseId: Int) async {
        guard canSavePos(for: senseId) else { return }
        guard senses.contains(where: { $0.id == senseId }) else { return }

        savingSenseIds.insert(senseId)
        errorMessage = nil
        defer { savingSenseIds.remove(senseId) }

        do {
            let updatedSense = try await dataSource.updateWordSense(
                senseId: senseId,
                pos: posText(for: senseId).trimmedNilIfEmpty
            )

            if let idx = senses.firstIndex(where: { $0.id == senseId }) {
                senses[idx] = updatedSense
            }

            if var currentWord = word,
               let idx = currentWord.senses.firstIndex(where: { $0.id == senseId }) {
                currentWord.senses[idx] = updatedSense
                word = currentWord
            }

            posTextBySenseId[senseId] = updatedSense.pos ?? ""
            rebuildSenseCellList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 단일 sense 입력을 현재 단어에 추가
    /// - Returns: 성공 여부 (sheet 닫을지 판단용)
    func addSenseToCurrentWord() async -> Bool {
        guard !isAddingSense else { return false }
        guard let word else {
            errorMessage = "단어 정보를 먼저 불러와 주세요."
            return false
        }

        let raw = addSenseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            errorMessage = "입력값이 비어 있습니다."
            return false
        }

        isAddingSense = true
        errorMessage = nil
        defer { isAddingSense = false }

        do {
            let parsed = try SenseBulkParser.parse(raw)
            guard parsed.items.count == 1 else {
                errorMessage = "한 번에 sense 1개만 추가할 수 있어요."
                return false
            }
            guard let item = parsed.items.first else {
                errorMessage = "sense 블록을 찾지 못했어요."
                return false
            }

            let inputWord = parsed.head.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let currentWord = word.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard inputWord == currentWord else {
                errorMessage = "입력 word(\(parsed.head))가 현재 단어(\(word.lemma))와 다릅니다."
                return false
            }

            let nextSenseCode = "s\(senses.count + 1)"
            let createdSense = try await dataSource.createWordSense(
                wordId: word.id,
                senseCode: nextSenseCode,
                explain: item.sense,
                pos: item.pos,
                cefr: item.cefr.uppercased(),
                translations: [
                    .init(lang: "ko", text: item.ko, explain: item.sense)
                ]
            )

            let exampleText = item.example.trimmingCharacters(in: .whitespacesAndNewlines)
            if !exampleText.isEmpty && exampleText != "-" {
                // 예문 본문은 example_sentence로 분리 저장합니다.
                let createdExample = try await ExampleDataSource.shared.createExample(
                    vocabularyId: word.id
                )
                _ = try await ExampleSentenceDataSource.shared.createExampleSentence(
                    payload: ExampleSentenceCreate(
                        exampleId: createdExample.id,
                        text: exampleText
                    )
                )
                _ = try await dataSource.attachExampleToWordSense(
                    senseId: createdSense.id,
                    exampleId: createdExample.id,
                    isPrime: true
                )
            }

            await load()
            addSenseText = ""
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(word: WordRead) {
        self.word = word
        self.senses = word.senses
        self.posTextBySenseId = Dictionary(
            uniqueKeysWithValues: word.senses.map { ($0.id, $0.pos ?? "") }
        )
        rebuildSenseCellList()
    }

    private func rebuildSenseCellList() {
        senseCellList = senses.map { sense in
            WordViewData.Sense(
                senseId: sense.id,
                wordId: sense.wordId,
                senseCode: sense.senseCode,
                tr1: sense.translations.first?.text ?? "",
                tr2: sense.translations.first(where: { $0.lang == "ja" })?.text ?? "",
                pos: sense.pos?.uppercased() ?? "",
                explain: sense.translations.first(where: { $0.lang == "ko" })?.explain ?? "",
                examples: sense.examples
                    .compactMap { $0.firstExampleSentence?.text }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
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

private extension String {
    var trimmedNilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
