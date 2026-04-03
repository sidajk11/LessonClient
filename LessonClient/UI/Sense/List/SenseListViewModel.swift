//
//  SenseListViewModel.swift
//  LessonClient
//
//  Created by ym on 3/9/26.
//

import Foundation

@MainActor
final class SenseListViewModel: ObservableObject {
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
    private let exampleDataSource = ExampleDataSource.shared
    private let autoGenerateWordSensesUseCase = AutoGenerateWordSensesUseCase.shared
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

            let result = try await autoGenerateWordSensesUseCase.generateSenses(
                for: lemmas,
                progressPrefix: "누락된 sense 추가 중...",
                onProgress: { [weak self] message in
                    self?.progressMessage = message
                }
            )

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
            let autoResult = try await autoGenerateWordSensesUseCase.autoGenerateSenses(
                from: rawInput,
                onProgress: { [weak self] message in
                    self?.progressMessage = message
                }
            )
            let lemmas = autoResult.lemmas
            let result = autoResult.generation

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

}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
