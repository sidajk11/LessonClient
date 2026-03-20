//
//  SenseDetailViewModel.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import Foundation

@MainActor
final class SenseDetailViewModel: ObservableObject {
    let senseId: Int

    @Published var sense: WordSenseRead?
    @Published var word: WordRead?
    @Published var examples: [Example] = []

    @Published var senseCode: String = ""
    @Published var pos: String = ""
    @Published var cefr: String = ""
    @Published var explain: String = ""
    @Published var translationsText: String = ""
    @Published var translationExplainsText: String = ""

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isDeleting: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let wordDataSource: WordDataSource
    private let exampleDataSource: ExampleDataSource

    init(
        senseId: Int,
        wordDataSource: WordDataSource = .shared,
        exampleDataSource: ExampleDataSource = .shared
    ) {
        self.senseId = senseId
        self.wordDataSource = wordDataSource
        self.exampleDataSource = exampleDataSource
    }

    var isSaveDisabled: Bool {
        isSaving || senseCode.trimmed.isEmpty || explain.trimmed.isEmpty
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedSense = try await wordDataSource.wordSense(senseId: senseId)

            async let loadedWordTask = try? wordDataSource.word(id: loadedSense.wordId)
            async let loadedExamplesTask = try? exampleDataSource.examples(senseId: senseId)

            let loadedWord = await loadedWordTask
            let loadedExamples = await loadedExamplesTask

            apply(
                sense: loadedSense,
                word: loadedWord,
                examples: loadedExamples ?? loadedSense.examples
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard !isSaving else { return }

        let trimmedSenseCode = senseCode.trimmed
        let trimmedExplain = explain.trimmed

        guard !trimmedSenseCode.isEmpty else {
            errorMessage = "senseCode를 입력해 주세요."
            return
        }

        guard !trimmedExplain.isEmpty else {
            errorMessage = "설명을 입력해 주세요."
            return
        }

        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        do {
            let updated = try await wordDataSource.updateWordSense(
                senseId: senseId,
                senseCode: trimmedSenseCode,
                explain: trimmedExplain,
                pos: pos.trimmedNilIfEmpty,
                cefr: cefr.trimmedNilIfEmpty?.uppercased(),
                translations: mergedTranslations()
            )

            async let loadedWordTask = try? wordDataSource.word(id: updated.wordId)
            async let loadedExamplesTask = try? exampleDataSource.examples(senseId: senseId)

            let loadedWord = await loadedWordTask
            let loadedExamples = await loadedExamplesTask

            apply(
                sense: updated,
                word: loadedWord,
                examples: loadedExamples ?? updated.examples
            )
            infoMessage = "저장되었습니다."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        errorMessage = nil
        infoMessage = nil
        defer { isDeleting = false }

        do {
            try await wordDataSource.deleteWordSense(senseId: senseId)
            infoMessage = "삭제되었습니다."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(sense: WordSenseRead, word: WordRead?, examples: [Example]) {
        self.sense = sense
        self.word = word
        self.examples = examples

        senseCode = sense.senseCode
        pos = sense.pos ?? ""
        cefr = sense.cefr ?? ""
        explain = sense.explain
        translationsText = sense.translations
            .sorted { $0.lang < $1.lang }
            .map { "\($0.lang): \($0.text)" }
            .joined(separator: "\n")
        translationExplainsText = sense.translations
            .filter { !$0.explain.trimmed.isEmpty }
            .sorted { $0.lang < $1.lang }
            .map { "\($0.lang): \($0.explain)" }
            .joined(separator: "\n")
    }

    private func mergedTranslations() -> [WordSenseTranslation] {
        let textByLang = parseLocalizedLines(from: translationsText)
        let explainByLang = parseLocalizedLines(from: translationExplainsText)
        let languages = Set(textByLang.keys).union(explainByLang.keys).sorted()

        return languages.compactMap { lang in
            let text = textByLang[lang, default: ""].trimmed
            let explain = explainByLang[lang, default: ""].trimmed
            guard !text.isEmpty || !explain.isEmpty else { return nil }
            return WordSenseTranslation(lang: lang, text: text, explain: explain)
        }
    }

    private func parseLocalizedLines(from raw: String) -> [String: String] {
        raw
            .components(separatedBy: .newlines)
            .map(\.trimmed)
            .reduce(into: [String: String]()) { partialResult, line in
                guard !line.isEmpty, let parsed = line.parseLocalizedString() else { return }
                partialResult[parsed.langCode] = parsed.text
            }
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
