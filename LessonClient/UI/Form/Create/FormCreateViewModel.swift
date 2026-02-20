//
//  FormCreateViewModel.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import Foundation

@MainActor
final class FormCreateViewModel: ObservableObject {

    struct DraftRow: Identifiable, Hashable {
        enum Status: Hashable {
            case ready
            case saving
            case saved(formId: Int)
            case failed(message: String)
            case skipped(reason: String)
        }

        let id = UUID()
        var word: String
        var form: String
        var formType: String?
        var explainKo: String?
        var status: Status = .ready
    }

    // Input
    @Published var rawText: String = "" {
        didSet { scheduleAutoParse() }
    }

    // Parsed rows
    @Published var rows: [DraftRow] = []

    // UI State
    @Published var isParsing: Bool = false
    @Published var isSaving: Bool = false

    /// 파싱/저장 결과를 요약해서 보여주는 메시지
    @Published var statusMessage: String? = nil

    private let wordDS = WordDataSource.shared
    private let formDS = WordFormDataSource.shared

    // Debounce
    private var parseTask: Task<Void, Never>?
    private let debounceNanos: UInt64 = 250_000_000 // 0.25s

    private func scheduleAutoParse() {
        if isSaving { return }

        parseTask?.cancel()
        parseTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanos)
            if Task.isCancelled { return }
            self.parseNow()
        }
    }

    // MARK: - Parsing

    func parseNow() {
        isParsing = true
        defer { isParsing = false }

        statusMessage = nil
        rows.removeAll()

        let blocks = splitIntoBlocks(rawText)
        let totalBlocks = blocks.count

        var parsed: [DraftRow] = []
        var skippedBlocks = 0
        var missingRequired = 0

        for block in blocks {
            if let row = parseBlock(block) {
                // required 검사
                let w = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
                let f = row.form.trimmingCharacters(in: .whitespacesAndNewlines)

                var r = row
                if w.isEmpty || f.isEmpty {
                    r.status = .failed(message: "word/form is required")
                    missingRequired += 1
                } else {
                    r.status = .ready
                }
                parsed.append(r)
            } else {
                skippedBlocks += 1
            }
        }

        rows = parsed

        // 파싱 요약 메시지
        let parsedCount = rows.count
        let failedCount = rows.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
        let readyCount = rows.filter { $0.status == .ready }.count

        if totalBlocks == 0 {
            statusMessage = "Parsing: 입력이 비어있습니다."
        } else {
            statusMessage =
"""
Parsing: blocks=\(totalBlocks), parsed=\(parsedCount), ready=\(readyCount), invalid=\(failedCount), skipped=\(skippedBlocks)
"""
        }
    }

    private func splitIntoBlocks(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // 빈 줄 기준 분리
        let parts = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 연속 빈줄 방어
        return parts.flatMap { part in
            part
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private func parseBlock(_ block: String) -> DraftRow? {
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

        // word/form이 없으면 블록 자체를 스킵
        guard let word = dict["word"], let form = dict["form"] else { return nil }

        let formType = dict["form_type"]
        let explainKo = dict["explain_ko"]

        return DraftRow(
            word: word,
            form: form,
            formType: (formType?.isEmpty == true ? nil : formType),
            explainKo: (explainKo?.isEmpty == true ? nil : explainKo),
            status: .ready
        )
    }

    // MARK: - Save

    func saveAll() async {
        // 저장 직전에 디바운스 파싱 대기 중이면 즉시 반영
        parseTask?.cancel()
        parseNow()

        let indices = rows.indices

        // 저장 대상 선별
        var toSave: [Int] = []
        var skipped: [Int] = []

        for i in indices {
            switch rows[i].status {
            case .failed(let msg):
                rows[i].status = .skipped(reason: msg)
                skipped.append(i)
            case .ready, .saved, .saving, .skipped:
                // saved는 보통 저장 대상에서 제외하고 싶으면 여기서 제외 가능
                // 지금은 "ready만 저장"으로 동작
                break
            }
        }

        toSave = indices.filter { idx in
            if case .ready = rows[idx].status { return true }
            return false
        }

        guard !toSave.isEmpty else {
            statusMessage = "Save: 저장할 항목이 없습니다. (ready=0, skipped=\(skipped.count))"
            return
        }

        isSaving = true
        defer { isSaving = false }

        statusMessage = "Save: 시작 (count=\(toSave.count))"

        for i in toSave {
            rows[i].status = .saving
        }

        var success = 0
        var fail = 0

        for i in toSave {
            let word = rows[i].word.trimmingCharacters(in: .whitespacesAndNewlines)
            let form = rows[i].form.trimmingCharacters(in: .whitespacesAndNewlines)
            let formType = rows[i].formType?.trimmingCharacters(in: .whitespacesAndNewlines)

            let explainKo = rows[i].explainKo?.trimmingCharacters(in: .whitespacesAndNewlines)
            let translations: [WordFormTranslationSchema]? = {
                guard let explainKo, !explainKo.isEmpty else { return nil }
                return [WordFormTranslationSchema(lang: "ko", explain: explainKo)]
            }()

            do {
                // 1) word -> word_id 조회
                let wordRead = try await wordDS.getWord(word: word)

                // 2) create word-form
                let created = try await formDS.createWordForm(
                    wordId: wordRead.id,
                    form: form,
                    formType: (formType?.isEmpty == true ? nil : formType),
                    translations: translations
                )

                rows[i].status = .saved(formId: created.id)
                success += 1
            } catch {
                rows[i].status = .failed(message: error.localizedDescription)
                fail += 1
            }
        }

        let skippedCount = rows.filter {
            if case .skipped = $0.status { return true }
            return false
        }.count

        statusMessage = "Save: done ✅ success=\(success), failed=\(fail), skipped=\(skippedCount)"
    }

    // MARK: - Utilities

    func clearAll() {
        parseTask?.cancel()
        rawText = ""
        rows = []
        statusMessage = nil
    }
}
