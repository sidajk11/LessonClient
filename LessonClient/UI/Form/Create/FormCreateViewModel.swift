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
    @Published var isAutoAdding: Bool = false
    @Published private(set) var isAutoSessionActive: Bool = false
    @Published private(set) var autoCurrentWord: String? = nil
    @Published private(set) var autoCurrentIndex: Int = 0
    @Published private(set) var autoTotalCount: Int = 0

    /// 파싱/저장 결과를 요약해서 보여주는 메시지
    @Published var statusMessage: String? = nil

    private let wordDS = WordDataSource.shared
    private let formDS = WordFormDataSource.shared
    private let parser = FormBlocksParser()
    private let openAIClient = OpenAIClient()
    private var autoWordsQueue: [WordRead] = []

    // Debounce
    private var parseTask: Task<Void, Never>?
    private let debounceNanos: UInt64 = 250_000_000 // 0.25s

    private func scheduleAutoParse() {
        if isSaving || isAutoAdding { return }

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

        let result = parser.parse(rawText: rawText)
        rows = result.rows

        // 파싱 요약 메시지
        let parsedCount = rows.count
        let failedCount = rows.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
        let readyCount = rows.filter { $0.status == .ready }.count

        if result.totalBlocks == 0 {
            statusMessage = "Parsing: 입력이 비어있습니다."
        } else {
            statusMessage =
"""
Parsing: blocks=\(result.totalBlocks), parsed=\(parsedCount), ready=\(readyCount), invalid=\(failedCount), skipped=\(result.skippedBlocks)
"""
        }
    }

    // MARK: - Save

    func saveAll() async {
        // 저장 직전에 디바운스 파싱 대기 중이면 즉시 반영
        parseTask?.cancel()
        parseNow()
        let result = await saveCurrentRows(stopOnFailure: false)

        // 자동추가 세션에서는 저장 성공 시 다음 단어를 자동 처리
        if isAutoSessionActive, result.fail == 0, result.success > 0 {
            await moveToNextWordWithoutSaving()
        }
    }

    func autoAddMissingForms() async {
        guard !isAutoAdding, !isSaving else { return }

        parseTask?.cancel()
        isAutoAdding = true
        defer { isAutoAdding = false }

        do {
            var words = try await fetchWordsWithoutForms(limit: 200, offset: 20)
            guard !words.isEmpty else {
                statusMessage = "AutoAdd: 폼이 없는 단어가 없습니다."
                resetAutoSession()
                return
            }

            words = words.filter { !$0.lemma.contains("'") && !$0.lemma.contains(" ") }
            words = words.filter { NL.getLemma(of: $0.lemma) == $0.lemma }
            guard !words.isEmpty else {
                statusMessage = "AutoAdd: 처리 가능한 단어가 없습니다."
                resetAutoSession()
                return
            }
            

            autoWordsQueue = words
            autoTotalCount = words.count
            isAutoSessionActive = true

            var totalSavedForms = 0
            var failedWords: [String] = []
            for idx in autoWordsQueue.indices {
                autoCurrentIndex = idx
                autoCurrentWord = autoWordsQueue[idx].lemma.trimmingCharacters(in: .whitespacesAndNewlines)
                clearDraftForNextWord()

                do {
                    try await generateAndParseCurrentWord()

                    let saveResult = await saveCurrentRows(stopOnFailure: true)
                    guard saveResult.fail == 0 else {
                        throw AutoAddError.saveFailed(word: autoCurrentWord ?? "", reason: "save failure")
                    }
                    guard saveResult.success > 0 else {
                        throw AutoAddError.saveFailed(word: autoCurrentWord ?? "", reason: "no saved rows")
                    }
                    totalSavedForms += saveResult.success
                } catch {
                    let failedWord = autoCurrentWord ?? "(unknown)"
                    failedWords.append(failedWord)
                    statusMessage = "AutoAdd: '\(failedWord)' 실패 - \(error.localizedDescription). 다음 단어를 진행합니다."
                    continue
                }
            }

            statusMessage = "AutoAdd: done ✅ words=\(autoTotalCount), forms=\(totalSavedForms), failed=\(failedWords.count)"
            resetAutoSession(keepCurrentWord: true)
        } catch {
            statusMessage = "AutoAdd: 중단 - \(error.localizedDescription)"
            resetAutoSession()
        }
    }

    func moveToNextWordWithoutSaving() async {
        guard isAutoSessionActive else { return }
        guard !isAutoAdding, !isSaving else { return }

        let skippedWord = autoCurrentWord
        let nextIndex = autoCurrentIndex + 1
        guard nextIndex < autoWordsQueue.count else {
            statusMessage = "AutoAdd: 모든 단어 처리를 완료했습니다."
            resetAutoSession(keepCurrentWord: true)
            return
        }

        if let skippedWord {
            statusMessage = "AutoAdd: '\(skippedWord)' 건너뜀. 다음 단어로 이동합니다."
        }
        autoCurrentIndex = nextIndex
        autoCurrentWord = autoWordsQueue[autoCurrentIndex].lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        clearDraftForNextWord()
        statusMessage = "AutoAdd: (\(autoCurrentIndex + 1)/\(autoTotalCount)) '\(autoCurrentWord ?? "")' 준비됨. OpenAI 호출 버튼을 눌러주세요."
    }

    func callOpenAIForCurrentWord() async {
        guard isAutoSessionActive else { return }
        guard !isAutoAdding, !isSaving else { return }

        parseTask?.cancel()
        isAutoAdding = true
        defer { isAutoAdding = false }

        do {
            try await generateAndParseCurrentWord()
        } catch {
            statusMessage = "AutoAdd: 중단 - \(error.localizedDescription)"
        }
    }

    private func generateAndParseCurrentWord() async throws {
        guard isAutoSessionActive else { return }
        guard autoCurrentIndex >= 0, autoCurrentIndex < autoWordsQueue.count else {
            resetAutoSession()
            return
        }

        let word = autoWordsQueue[autoCurrentIndex]
        let lemma = word.lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lemma.isEmpty else {
            throw AutoAddError.invalidWord(message: "empty lemma (wordId=\(word.id))")
        }

        autoCurrentWord = lemma
        statusMessage = "AutoAdd: (\(autoCurrentIndex + 1)/\(autoTotalCount)) generating '\(lemma)'"

        let prompt = Prompt.makeFormPrompt(for: lemma)
        let generated = try await openAIClient.generateText(prompt: prompt)

        rawText = generated
        parseTask?.cancel()
        parseNow()

        let readyCount = rows.filter {
            if case .ready = $0.status { return true }
            return false
        }.count
        guard readyCount > 0 else {
            throw AutoAddError.noParsableRows(word: lemma)
        }

        statusMessage = "AutoAdd: (\(autoCurrentIndex + 1)/\(autoTotalCount)) '\(lemma)' 파싱 완료 (ready=\(readyCount))"
    }

    private func saveCurrentRows(stopOnFailure: Bool) async -> (success: Int, fail: Int, skipped: Int) {

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
            return (0, 0, skipped.count)
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
                let derivedWordId = try? await wordDS.getWord(word: form).id

                // 2) create word-form
                let created = try await formDS.createWordForm(
                    wordId: wordRead.id,
                    derivedWordId: derivedWordId,
                    form: form,
                    formType: (formType?.isEmpty == true ? nil : formType),
                    translations: translations
                )

                rows[i].status = .saved(formId: created.id)
                success += 1
            } catch {
                rows[i].status = .failed(message: error.localizedDescription)
                fail += 1
                if stopOnFailure { break }
            }
        }

        let skippedCount = rows.filter {
            if case .skipped = $0.status { return true }
            return false
        }.count

        statusMessage = "Save: done ✅ success=\(success), failed=\(fail), skipped=\(skippedCount)"
        return (success, fail, skippedCount)
    }

    private func fetchWordsWithoutForms(limit: Int = 200, offset: Int = 0) async throws -> [WordRead] {
        try await wordDS.listWordsWithoutForms(limit: limit, offset: offset)
    }

    private enum AutoAddError: LocalizedError {
        case invalidWord(message: String)
        case noParsableRows(word: String)
        case saveFailed(word: String, reason: String)

        var errorDescription: String? {
            switch self {
            case .invalidWord(let message):
                return "invalid word: \(message)"
            case .noParsableRows(let word):
                return "no parsable forms for '\(word)'"
            case .saveFailed(let word, let reason):
                return "save failed for '\(word)': \(reason)"
            }
        }
    }

    var canMoveNextWord: Bool {
        isAutoSessionActive && autoCurrentIndex + 1 < autoTotalCount
    }

    var autoProgressText: String? {
        guard isAutoSessionActive else { return nil }
        guard let autoCurrentWord else { return nil }
        return "\(autoCurrentIndex + 1)/\(autoTotalCount) • \(autoCurrentWord)"
    }

    var currentWordText: String? {
        guard isAutoSessionActive else { return nil }
        guard let autoCurrentWord else { return nil }
        return "현재 단어: \(autoCurrentWord)"
    }

    private func clearDraftForNextWord() {
        parseTask?.cancel()
        rawText = ""
        rows = []
        parseTask?.cancel()
    }

    private func resetAutoSession(keepCurrentWord: Bool = false) {
        isAutoSessionActive = false
        autoWordsQueue = []
        autoCurrentIndex = 0
        autoTotalCount = 0
        if !keepCurrentWord { autoCurrentWord = nil }
    }

    // MARK: - Utilities

    func clearAll() {
        parseTask?.cancel()
        resetAutoSession()
        rawText = ""
        rows = []
        statusMessage = nil
    }
}
