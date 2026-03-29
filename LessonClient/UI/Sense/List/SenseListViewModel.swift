//
//  SenseListViewModel.swift
//  LessonClient
//
//  Created by ym on 3/9/26.
//

import Foundation

@MainActor
final class SenseListViewModel: ObservableObject {
    private struct GeneratedFormRow {
        let word: String
        let form: String
        let formType: String?
    }

    private struct SenseGenerationResult {
        var createdWords: Int = 0
        var createdSenses: Int = 0
        var createdForms: Int = 0
        var createdPhrases: Int = 0
        var skipped: Int = 0
        var failures: [String] = []
    }

    private enum AutoGenerateError: LocalizedError {
        case emptyInput
        case noLemmas
        case invalidLemmaOutput(String)
        case mismatchedHead(expected: String, actual: String)

        var errorDescription: String? {
            switch self {
            case .emptyInput:
                return "입력한 단어가 없습니다."
            case .noLemmas:
                return "lemma를 추출하지 못했습니다."
            case .invalidLemmaOutput(let raw):
                return "lemma 파싱 실패: \(raw)"
            case .mismatchedHead(let expected, let actual):
                return "Sense 결과 word 불일치: expected=\(expected), actual=\(actual)"
            }
        }
    }

    struct Row: Identifiable {
        let wordId: Int
        let lemma: String
        let normalized: String
        let kind: String
        let sense: WordSenseRead

        var id: Int { sense.id }
    }

    @Published var items: [Row] = []
    @Published var missingLemmas: [String] = []
    @Published var q: String = ""
    @Published var isLoading: Bool = false
    @Published var isLoadingMissingLemmas: Bool = false
    @Published var isAddingMissingSenses: Bool = false
    @Published var isAutoGeneratingSenses: Bool = false
    @Published var progressMessage: String?
    @Published var errorMessage: String?

    private let dataSource = WordDataSource.shared
    private let formDataSource = WordFormDataSource.shared
    private let phraseDataSource = PhraseDataSource.shared
    private let exampleDataSource = ExampleDataSource.shared
    private let openAIClient = OpenAIClient()
    private(set) var limit: Int = 50
    private var wordOffset: Int = 0
    private var hasMore: Bool = true

    var isBusy: Bool {
        isLoading || isLoadingMissingLemmas || isAddingMissingSenses || isAutoGeneratingSenses
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        wordOffset = 0
        hasMore = true
        defer { isLoading = false }

        await loadNextPage(replacingItems: true)
    }

    func loadMoreIfNeeded(current item: Row) async {
        guard !isLoading, hasMore else { return }
        guard item.id == items.last?.id else { return }

        isLoading = true
        defer { isLoading = false }

        await loadNextPage(replacingItems: false)
    }

    func loadMissingLemmas() async {
        guard !isLoadingMissingLemmas else { return }
        isLoadingMissingLemmas = true
        errorMessage = nil
        progressMessage = nil
        defer { isLoadingMissingLemmas = false }

        do {
            let missingWords = try await fetchMissingWords()
            missingLemmas = missingWords
            progressMessage = missingWords.isEmpty
                ? "서버에 없는 단어가 없습니다."
                : "서버에 없는 단어 \(missingWords.count)개"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addMissingSenses() async {
        guard !isAddingMissingSenses else { return }
        isAddingMissingSenses = true
        errorMessage = nil
        progressMessage = nil
        defer { isAddingMissingSenses = false }

        do {
            let lemmas = missingLemmas

            guard !lemmas.isEmpty else {
                progressMessage = "추가할 lemma가 없습니다."
                return
            }

            let result = try await generateSenses(for: lemmas, progressPrefix: "누락된 sense 추가 중...")

            await refresh()
            missingLemmas = try await fetchMissingWords()

            if result.failures.isEmpty {
                progressMessage = "누락된 sense 추가 완료 words=\(result.createdWords) senses=\(result.createdSenses) forms=\(result.createdForms) phrases=\(result.createdPhrases) skipped=\(result.skipped)"
                return
            }

            progressMessage = "누락된 sense 추가 완료 words=\(result.createdWords) senses=\(result.createdSenses) forms=\(result.createdForms) phrases=\(result.createdPhrases) skipped=\(result.skipped) failed=\(result.failures.count)"
            errorMessage = result.failures.prefix(3).joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func autoGenerateSenses(from rawInput: String) async {
        guard !isAutoGeneratingSenses else { return }
        isAutoGeneratingSenses = true
        errorMessage = nil
        progressMessage = nil
        defer { isAutoGeneratingSenses = false }

        do {
            let lemmas = try await normalizedLemmas(from: rawInput)
            let result = try await generateSenses(for: lemmas, progressPrefix: "Sense 자동 생성 중...")

            await refresh()
            missingLemmas = try await fetchMissingWords()

            if result.failures.isEmpty {
                progressMessage = "Sense 자동 생성 완료 lemmas=\(lemmas.count) words=\(result.createdWords) senses=\(result.createdSenses) forms=\(result.createdForms) phrases=\(result.createdPhrases) skipped=\(result.skipped)"
                return
            }

            progressMessage = "Sense 자동 생성 완료 lemmas=\(lemmas.count) words=\(result.createdWords) senses=\(result.createdSenses) forms=\(result.createdForms) phrases=\(result.createdPhrases) skipped=\(result.skipped) failed=\(result.failures.count)"
            errorMessage = result.failures.prefix(3).joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNextPage(replacingItems: Bool) async {
        do {
            let words = try await dataSource.listWords(
                q: q.trimmedNilIfEmpty,
                limit: limit,
                offset: wordOffset
            )

            let rows = makeRows(from: words, filter: q.trimmedNilIfEmpty)
            if replacingItems {
                items = rows
            } else {
                items.append(contentsOf: rows)
            }

            wordOffset += words.count
            hasMore = words.count == limit
        } catch {
            errorMessage = error.localizedDescription
            if replacingItems {
                items = []
            }
            hasMore = false
        }
    }

    private func makeRows(from words: [WordRead], filter: String?) -> [Row] {
        let loweredFilter = filter?.lowercased()

        return words
            .flatMap { word in
                word.senses.map { sense in
                    Row(
                        wordId: word.id,
                        lemma: word.lemma,
                        normalized: word.normalized,
                        kind: word.kind,
                        sense: sense
                    )
                }
            }
            .filter { row in
                guard let loweredFilter, !loweredFilter.isEmpty else { return true }
                return matches(row: row, loweredFilter: loweredFilter)
            }
            .sorted { lhs, rhs in
                let lhsLemma = lhs.lemma.lowercased()
                let rhsLemma = rhs.lemma.lowercased()
                if lhsLemma != rhsLemma {
                    return lhsLemma < rhsLemma
                }
                return lhs.sense.senseCode < rhs.sense.senseCode
            }
    }

    private func matches(row: Row, loweredFilter: String) -> Bool {
        if row.lemma.lowercased().contains(loweredFilter) { return true }
        if row.normalized.lowercased().contains(loweredFilter) { return true }
        if row.kind.lowercased().contains(loweredFilter) { return true }
        if row.sense.senseCode.lowercased().contains(loweredFilter) { return true }
        if row.sense.pos?.lowercased().contains(loweredFilter) == true { return true }
        if row.sense.cefr?.lowercased().contains(loweredFilter) == true { return true }
        if row.sense.explain.lowercased().contains(loweredFilter) { return true }
        if row.sense.translations.contains(where: { $0.text.lowercased().contains(loweredFilter) }) { return true }
        return false
    }

    private func fetchMissingLemmas() async throws -> [String] {
        try await fetchMissingSenseCandidateLemmas()
    }

    private func fetchMissingSenseCandidateLemmas() async throws -> [String] {
        let examples = try await exampleDataSource.examplesWithoutSenseTokens(limit: 200)
        return candidateLemmas(from: examples)
    }

    private func fetchMissingWords() async throws -> [String] {
        let lemmas = try await fetchMissingSenseCandidateLemmas()
        var missingWords: [String] = []

        for lemma in lemmas {
            if (try? await dataSource.getWord(word: lemma)) == nil {
                missingWords.append(lemma)
            }
        }

        return missingWords
    }

    private func candidateLemmas(from examples: [Example]) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []

        for example in examples {
            guard let text = example.firstExampleSentence?.text else { continue }
            for lemma in SentenseParser.lemmas(in: text) {
                let trimmed = lemma.trimmed
                guard isLemmaCandidate(trimmed) else { continue }

                let key = trimmed.lowercased()
                guard seen.insert(key).inserted else { continue }
                output.append(trimmed)
            }
        }

        return output
    }

    private func isLemmaCandidate(_ lemma: String) -> Bool {
        guard !lemma.isEmpty else { return false }
        guard !lemma.contains(" ") else { return false }
        guard lemma.rangeOfCharacter(from: .letters) != nil else { return false }
        return true
    }

    private func ensureWord(for lemma: String) async throws -> (word: WordRead, wordWasCreated: Bool) {
        if let existing = try? await dataSource.getWord(word: lemma) {
            return (existing, false)
        }

        let created = try await dataSource.createWord(lemma: lemma)
        return (created, true)
    }

    private func serverSenses(lemma: String) async throws -> [WordSenseRead] {
        do {
            return try await dataSource.listWordSensesByLemma(lemma: lemma, limit: 100)
        } catch APIClient.APIError.http(let statusCode, _) where statusCode == 404 {
            return []
        }
    }

    private func normalizedLemmas(from rawInput: String) async throws -> [String] {
        let trimmedInput = rawInput.trimmed
        guard !trimmedInput.isEmpty else { throw AutoGenerateError.emptyInput }

        progressMessage = "lemma 추출 중..."
        let generated = try await openAIClient.generateText(
            prompt: Prompt.makeLemmaPrompt(for: trimmedInput)
        )
        let lemmas = parseLemmaOutput(generated)

        guard !lemmas.isEmpty else {
            throw generated.trimmed.isEmpty
                ? AutoGenerateError.noLemmas
                : AutoGenerateError.invalidLemmaOutput(generated)
        }

        return lemmas
    }

    private func parseLemmaOutput(_ rawOutput: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n")
        let tokens = rawOutput
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: separators)

        var seen: Set<String> = []
        var lemmas: [String] = []

        for token in tokens {
            let lemma = sanitizeGeneratedLemma(token)
            guard !lemma.isEmpty else { continue }

            let key = lemma.lowercased()
            guard seen.insert(key).inserted else { continue }
            lemmas.append(lemma)
        }

        return lemmas
    }

    private func sanitizeGeneratedLemma(_ token: String) -> String {
        var value = token.trimmed
        guard !value.isEmpty else { return "" }

        if let colonIndex = value.firstIndex(of: ":") {
            let key = value[..<colonIndex].trimmed.lowercased()
            if key == "lemma" || key == "lemmas" || key == "word" || key == "words" {
                value = String(value[value.index(after: colonIndex)...]).trimmed
            }
        }

        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`[](){}.-•0123456789 ").union(.whitespacesAndNewlines))
        return value
    }

    private func generateSenses(for lemmas: [String], progressPrefix: String) async throws -> SenseGenerationResult {
        var result = SenseGenerationResult()

        for (index, rawLemma) in lemmas.enumerated() {
            let lemma = rawLemma.trimmed
            guard !lemma.isEmpty else { continue }

            progressMessage = "\(progressPrefix) (\(index + 1)/\(lemmas.count)) \(lemma)"

            do {
                let existingSenses = try await serverSenses(lemma: lemma)
                if !existingSenses.isEmpty {
                    let ensuredWord = try await ensureWord(for: lemma)
                    if ensuredWord.wordWasCreated {
                        result.createdWords += 1
                    }
                    let createdForms = try await ensureFormsIfNeeded(for: lemma, word: ensuredWord.word)
                    result.createdForms += createdForms
                    if try await ensurePhraseIfNeeded(for: lemma, senses: existingSenses) {
                        result.createdPhrases += 1
                    }
                    result.skipped += 1
                    continue
                }

                let generated = try await openAIClient.generateText(
                    prompt: Prompt.makeSensePrompt(for: lemma)
                )
                let parsed = try SenseBulkParser.parse(generated)
                let parsedHead = parsed.head.trimmed
                if !parsedHead.isEmpty, parsedHead.lowercased().replacingOccurrences(of: "-", with: " ") != lemma.lowercased().replacingOccurrences(of: "’", with: "'") {
                    throw AutoGenerateError.mismatchedHead(expected: lemma, actual: parsedHead)
                }

                let ensuredWord = try await ensureWord(for: lemma)
                if ensuredWord.wordWasCreated {
                    result.createdWords += 1
                }

                let createdCount = try await createSenses(from: parsed.items, for: ensuredWord.word)
                guard createdCount > 0 else {
                    result.failures.append("\(lemma): empty senses")
                    continue
                }

                let createdForms = try await ensureFormsIfNeeded(for: lemma, word: ensuredWord.word)
                result.createdForms += createdForms

                if try await ensurePhraseIfNeeded(for: lemma, items: parsed.items) {
                    result.createdPhrases += 1
                }

                result.createdSenses += createdCount
            } catch {
                result.failures.append("\(lemma): \(error.localizedDescription)")
            }
        }

        return result
    }

    private func createSenses(from items: [SenseBulkParser.Item], for word: WordRead) async throws -> Int {
        var created = 0

        for (senseIndex, item) in items.enumerated() {
            let sense = try await dataSource.createWordSense(
                wordId: word.id,
                senseCode: "s\(senseIndex + 1)",
                explain: item.sense,
                pos: item.pos.trimmedNilIfEmpty,
                cefr: item.cefr.uppercased().trimmedNilIfEmpty,
                translations: [
                    .init(lang: "ko", text: item.ko, explain: "")
                ]
            )

            let exampleText = item.example.trimmed
            if !exampleText.isEmpty, exampleText != "-" {
                if let example = try? await exampleDataSource.createExample(sentence: exampleText, vocabularyId: nil) {
                    _ = try? await dataSource.attachExampleToWordSense(
                        senseId: sense.id,
                        exampleId: example.id,
                        isPrime: true
                    )
                }
            }

            created += 1
        }

        return created
    }

    private func ensureFormsIfNeeded(for lemma: String, word: WordRead) async throws -> Int {
        guard shouldGenerateForms(for: lemma) else { return 0 }

        let existingForms = try await formDataSource.listWordForms(wordId: word.id, limit: 1, offset: 0)
        guard existingForms.isEmpty else { return 0 }

        let generated = try await openAIClient.generateText(
            prompt: Prompt.makeFormPrompt(for: lemma)
        )
        let rows = parseFormOutput(generated)
        guard !rows.isEmpty else { return 0 }

        var created = 0
        var seen: Set<String> = []

        for row in rows {
            let form = row.form.trimmed
            guard !form.isEmpty else { continue }

            let formType = row.formType?.trimmedNilIfEmpty
            let dedupeKey = "\(form.lowercased())|\((formType ?? "").lowercased())"
            guard seen.insert(dedupeKey).inserted else { continue }

            let derivedWordId = try? await dataSource.getWord(word: form).id

            _ = try await formDataSource.createWordForm(
                wordId: word.id,
                derivedWordId: derivedWordId,
                form: form,
                formType: formType,
                translations: nil
            )
            created += 1
        }

        return created
    }

    private func parseFormOutput(_ rawOutput: String) -> [GeneratedFormRow] {
        let normalized = rawOutput
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let blocks = normalized
            .components(separatedBy: "\n\n")
            .map(\.trimmed)
            .filter { !$0.isEmpty }

        return blocks.compactMap { block in
            var dict: [String: String] = [:]

            for line in block.components(separatedBy: .newlines).map(\.trimmed) where !line.isEmpty {
                guard let idx = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<idx]).trimmed.lowercased()
                let value = String(line[line.index(after: idx)...]).trimmed
                guard !key.isEmpty else { continue }
                dict[key] = value
            }

            guard
                let word = dict["word"]?.trimmed,
                let form = dict["form"]?.trimmed,
                !word.isEmpty,
                !form.isEmpty
            else {
                return nil
            }

            return GeneratedFormRow(
                word: word,
                form: form,
                formType: dict["form_type"]?.trimmedNilIfEmpty
            )
        }
    }

    private func ensurePhraseIfNeeded(for lemma: String, items: [SenseBulkParser.Item]) async throws -> Bool {
        let translations = phraseTranslations(from: items.map(\.ko))
        return try await ensurePhraseIfNeeded(for: lemma, translations: translations)
    }

    private func ensurePhraseIfNeeded(for lemma: String, senses: [WordSenseRead]) async throws -> Bool {
        let translations = phraseTranslations(
            from: senses.flatMap { sense in
                sense.translations
                    .filter { $0.lang.lowercased() == "ko" }
                    .map(\.text)
            }
        )
        return try await ensurePhraseIfNeeded(for: lemma, translations: translations)
    }

    private func ensurePhraseIfNeeded(for lemma: String, translations: [PhraseTranslationSchema]?) async throws -> Bool {
        guard isPhraseLikeLemma(lemma) else { return false }

        if let existing = try await findPhrase(text: lemma) {
            if existing.translations.isEmpty, let translations, !translations.isEmpty {
                _ = try await phraseDataSource.updatePhrase(
                    id: existing.id,
                    text: nil,
                    translations: translations
                )
            }
            return false
        }

        _ = try await phraseDataSource.createPhrase(text: lemma, translations: translations)
        return true
    }

    private func findPhrase(text: String) async throws -> PhraseRead? {
        let trimmedText = text.trimmed
        guard !trimmedText.isEmpty else { return nil }

        let rows = try await phraseDataSource.listPhrases(q: trimmedText, limit: 20, offset: 0)
        return rows.first { $0.text.trimmed.caseInsensitiveCompare(trimmedText) == .orderedSame }
    }

    private func phraseTranslations(from values: [String]) -> [PhraseTranslationSchema]? {
        var seen: Set<String> = []
        let uniqueValues = values
            .map(\.trimmed)
            .filter { !$0.isEmpty && $0 != "-" }
            .filter { seen.insert($0.lowercased()).inserted }

        guard !uniqueValues.isEmpty else { return nil }
        return [.init(lang: "ko", text: uniqueValues.joined(separator: " / "))]
    }

    private func isPhraseLikeLemma(_ lemma: String) -> Bool {
        lemma.contains(" ")
    }

    private func shouldGenerateForms(for lemma: String) -> Bool {
        !isPhraseLikeLemma(lemma)
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
