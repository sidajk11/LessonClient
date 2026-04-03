//
//  VocabularyListViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

@MainActor
final class VocabularyListViewModel: ObservableObject {
    private let openAIClient = OpenAIClient()
    private var lessonTopicByLessonId: [Int: String] = [:]
    private let vocabularyLinkAuditUseCase = VocabularyLinkAuditUseCase.shared
    private var hasLoadedOnce = false

    // UI State
    @Published var items: [Vocabulary] = []
    @Published var searchText: String = ""
    @Published var levelText: String = ""     // free-form, parsed to Int?
    @Published var unitText: String = ""      // free-form, parsed to Int?
    @Published var showOnlyWithoutExamples: Bool = false
    @Published var showOnlyAuditFailures: Bool = false
    @Published var isSentenceGeneratorPresented: Bool = false
    @Published var sentenceCefr: String = "B1"
    @Published var isLoading: Bool = false
    @Published var isGeneratingExamples: Bool = false
    @Published var isCheckingLinks: Bool = false
    @Published var isApplyingAuditResults: Bool = false
    @Published var linkAuditByVocabularyId: [Int: VocabularyLinkAuditResult] = [:]
    @Published var auditFailureMessageByVocabularyId: [Int: String] = [:]
    @Published var unitByVocabularyId: [Int: Int] = [:]
    @Published var progressText: String?
    @Published var error: String?
    @Published var info: String?

    var displayedItems: [Vocabulary] {
        items.filter { vocabulary in
            !showOnlyAuditFailures || auditFailureMessageByVocabularyId[vocabulary.id] != nil
        }
    }

    var canGenerateExamples: Bool {
        !displayedItems.isEmpty && !isLoading && !isGeneratingExamples && !isApplyingAuditResults
    }

    var canCheckLinks: Bool {
        !items.isEmpty && !isLoading && !isGeneratingExamples && !isCheckingLinks && !isApplyingAuditResults
    }

    var canApplyAuditResults: Bool {
        !isLoading &&
        !isGeneratingExamples &&
        !isCheckingLinks &&
        !isApplyingAuditResults &&
        displayedItems.contains { vocabulary in
            linkAuditByVocabularyId[vocabulary.id]?.requiresSenseFix == true
        }
    }

    // Initial load
    func load() async {
        guard !hasLoadedOnce else { return }
        await reload()
    }

    // Search action (q + level)
    func search() async {
        await reload()
    }

    func openSentenceGenerator() {
        if sentenceCefr.trimmed.isEmpty { sentenceCefr = "B1" }
        isSentenceGeneratorPresented = true
    }

    func checkCurrentItems() async {
        guard !isCheckingLinks else { return }

        let targetItems = inspectionTargetItems
        guard !targetItems.isEmpty else {
            error = "검사할 단어가 없습니다."
            return
        }

        error = nil
        info = nil
        isCheckingLinks = true
        linkAuditByVocabularyId = [:]
        auditFailureMessageByVocabularyId = [:]
        defer { isCheckingLinks = false }

        let result = await vocabularyLinkAuditUseCase.audit(
            vocabularies: targetItems,
            onProgress: { [weak self] message in
                self?.progressText = message
            }
        )

        linkAuditByVocabularyId = result.auditsByVocabularyId
        auditFailureMessageByVocabularyId = result.failureMessagesByVocabularyId
        progressText = "연결 검사 완료 mismatch=\(result.mismatchCount) failed=\(result.failureCount)"
        if result.mismatchCount > 0 {
            info = "센스수정 필요 \(result.mismatchCount)개"
        } else if result.failureCount == 0 {
            info = "모든 단어가 현재 연결과 일치합니다."
        }
        if result.failureCount > 0 {
            error = "일부 단어 검사에 실패했습니다. failed=\(result.failureCount)"
        }
    }

    func applyAuditResultsToCurrentItems() async {
        guard !isApplyingAuditResults else { return }

        let targetItems = displayedItems
        let targetVocabularyIds = Set(targetItems.map(\.id))
        let targetAudits = linkAuditByVocabularyId.filter {
            targetVocabularyIds.contains($0.key) && $0.value.requiresSenseFix
        }

        guard !targetItems.isEmpty else {
            error = "적용할 단어가 없습니다."
            return
        }
        guard !linkAuditByVocabularyId.isEmpty else {
            error = "먼저 검사해 주세요."
            return
        }
        guard !targetAudits.isEmpty else {
            error = "적용할 변경이 없습니다."
            return
        }

        error = nil
        info = nil
        isApplyingAuditResults = true
        defer { isApplyingAuditResults = false }

        let result = await vocabularyLinkAuditUseCase.applyAuditResults(
            to: targetItems,
            auditsByVocabularyId: targetAudits,
            onProgress: { [weak self] message in
                self?.progressText = message
            }
        )

        for updated in result.updatedVocabulariesById.values {
            if let itemIndex = items.firstIndex(where: { $0.id == updated.id }) {
                items[itemIndex] = updated
            }
        }
        for (vocabularyId, audit) in result.auditsByVocabularyId {
            linkAuditByVocabularyId[vocabularyId] = audit
        }

        progressText = "검사 결과 적용 완료 updated=\(result.updatedCount) failed=\(result.failureCount)"
        if result.updatedCount > 0 {
            info = "검사 결과 적용 완료 updated=\(result.updatedCount)"
        }
        if result.failureCount > 0 {
            error = "일부 단어 적용에 실패했습니다. failed=\(result.failureCount)"
        }
    }

    func generateExamplesForCurrentItems() async {
        guard !isGeneratingExamples else { return }

        let cefr = sentenceCefr.trimmed.isEmpty ? "B1" : sentenceCefr.trimmed.uppercased()
        let targetItems = displayedItems
        guard !targetItems.isEmpty else {
            error = "예문을 만들 단어가 없습니다."
            return
        }

        error = nil
        info = nil
        isGeneratingExamples = true
        progressText = nil
        defer { isGeneratingExamples = false }

        var createdWordCount = 0
        var createdExampleCount = 0
        var failures: [String] = []

        for (index, vocabulary) in targetItems.enumerated() {
            progressText = "예문 생성 중... (\(index + 1)/\(targetItems.count)) \(vocabulary.text)"

            do {
                let topic = try await lessonTopic(for: vocabulary)
                let prompt = Prompt.makeSentencePrompt(topic: topic, word: vocabulary.text, cefr: cefr)
                let response = try await openAIClient.generateText(prompt: prompt)
                let sentences = Self.parseGeneratedSentences(from: response)

                guard !sentences.isEmpty else {
                    failures.append("\(vocabulary.text): 생성 결과가 비어 있습니다.")
                    continue
                }

                var createdExamples: [Example] = []
                for sentence in sentences {
                    // 생성된 문장은 example_sentence로 저장합니다.
                    let createdExample = try await ExampleDataSource.shared.createExample(
                        vocabularyId: vocabulary.id
                    )
                    _ = try await ExampleSentenceDataSource.shared.createExampleSentence(
                        payload: ExampleSentenceCreate(
                            exampleId: createdExample.id,
                            text: sentence
                        )
                    )
                    let refreshedExample = try await ExampleDataSource.shared.example(id: createdExample.id)
                    createdExamples.append(refreshedExample)
                }

                createdWordCount += 1
                createdExampleCount += createdExamples.count
                appendExamples(createdExamples, toVocabularyId: vocabulary.id)
            } catch {
                failures.append("\(vocabulary.text): \(error.localizedDescription)")
            }
        }

        finalizeGenerationResult(
            createdWordCount: createdWordCount,
            createdExampleCount: createdExampleCount,
            failures: failures
        )
    }

    // Callbacks from child screens
    func didCreate(_ words: [Vocabulary]) {
        items.insert(contentsOf: normalize(words), at: 0)
    }
    func didImport(_ list: [Vocabulary]) {
        items.insert(contentsOf: normalize(list), at: 0)
    }

    // MARK: - Private
    private func reload() async {
        let trimmedLevel = levelText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unitText.trimmingCharacters(in: .whitespacesAndNewlines)
        let levelParam: Int? = trimmedLevel.isEmpty ? nil : Int(trimmedLevel)
        let unitParam: Int? = trimmedUnit.isEmpty ? nil : Int(trimmedUnit)

        if !trimmedLevel.isEmpty && levelParam == nil {
            error = "레벨은 숫자로 입력해 주세요."
            return
        }
        if !trimmedUnit.isEmpty && unitParam == nil {
            error = "Unit은 숫자로 입력해 주세요."
            return
        }

        do {
            error = nil
            isLoading = true
            defer { isLoading = false }

            var rows = try await fetchVocabularies(level: levelParam, unit: unitParam)
            if showOnlyWithoutExamples {
                rows = try await filterVocabulariesWithoutExamples(rows)
            }
            items = rows
            linkAuditByVocabularyId = [:]
            auditFailureMessageByVocabularyId = [:]
            unitByVocabularyId = unitMap(from: rows)
            hasLoadedOnce = true
        } catch {
            self.error = (error as NSError).localizedDescription
        }
        if !isGeneratingExamples && !isCheckingLinks && !isApplyingAuditResults {
            progressText = nil
        }
    }

    private var inspectionTargetItems: [Vocabulary] {
        if showOnlyAuditFailures && displayedItems.isEmpty {
            return items
        }
        return displayedItems
    }

    private func fetchVocabularies(level: Int?, unit: Int?) async throws -> [Vocabulary] {
        let query = searchText.trimmed

        if query.isEmpty {
            return try await VocabularyDataSource.shared.vocabularies(
                level: level,
                unit: unit
            )
        }

        return try await VocabularyDataSource.shared.searchVocabularys(
            q: query,
            level: level,
            unit: unit
        )
    }

    private func filterVocabulariesWithoutExamples(_ vocabularies: [Vocabulary]) async throws -> [Vocabulary] {
        var filtered: [Vocabulary] = []
        filtered.reserveCapacity(vocabularies.count)

        for (index, var vocabulary) in vocabularies.enumerated() {
            progressText = "예문 없는 단어 조회 중... (\(index + 1)/\(vocabularies.count)) \(vocabulary.text)"
            let examples = try await ExampleDataSource.shared.examples(wordId: vocabulary.id, limit: 1)
            vocabulary.examples = examples.map(VocabularyExampleRead.init)
            if examples.isEmpty {
                filtered.append(vocabulary)
            }
        }

        return filtered
    }

    private func normalize(_ vocabularies: [Vocabulary]) -> [Vocabulary] {
        vocabularies.map { vocabulary in
            var item = vocabulary
            // 예문 없는 항목 필터링 UI가 빈 배열을 바로 읽을 수 있게 유지합니다.
            if showOnlyWithoutExamples && item.examples.isEmpty {
                item.examples = []
            }
            return item
        }
    }

    private func unitMap(from vocabularies: [Vocabulary]) -> [Int: Int] {
        var unitsByVocabularyId: [Int: Int] = [:]
        for vocabulary in vocabularies {
            if let unit = vocabulary.unit {
                unitsByVocabularyId[vocabulary.id] = unit
            }
        }
        return unitsByVocabularyId
    }

    private func appendExamples(_ examples: [Example], toVocabularyId vocabularyId: Int) {
        guard let index = items.firstIndex(where: { $0.id == vocabularyId }) else { return }
        items[index].examples.append(contentsOf: examples.map(VocabularyExampleRead.init))
    }

    private func lessonTopic(for vocabulary: Vocabulary) async throws -> String {
        guard let lessonId = vocabulary.lessonId else {
            throw NSError(domain: "VocabularyListViewModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "레슨에 연결되지 않은 단어입니다."
            ])
        }

        if let cached = lessonTopicByLessonId[lessonId], !cached.isEmpty {
            return cached
        }

        let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
        let topic = lesson.translations.koText().trimmed.isEmpty
            ? lesson.translations.first?.topic.trimmed ?? ""
            : lesson.translations.koText().trimmed

        guard !topic.isEmpty else {
            throw NSError(domain: "VocabularyListViewModel", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "레슨 토픽이 비어 있습니다."
            ])
        }

        lessonTopicByLessonId[lessonId] = topic
        return topic
    }

    private static func parseGeneratedSentences(from text: String) -> [String] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .map { stripListMarker(from: $0).trimmed }
            .filter { !$0.isEmpty }

        var result: [String] = []
        var seen: Set<String> = []
        let regex = try? NSRegularExpression(pattern: #"[^.!?]+[.!?]"#)

        for line in lines {
            let matches = regex?.matches(
                in: line,
                range: NSRange(line.startIndex..<line.endIndex, in: line)
            ) ?? []

            if matches.isEmpty {
                appendSentence(line, to: &result, seen: &seen)
                continue
            }

            for match in matches {
                guard let range = Range(match.range, in: line) else { continue }
                appendSentence(String(line[range]), to: &result, seen: &seen)
            }
        }

        return result
    }

    private static func appendSentence(_ raw: String, to result: inout [String], seen: inout Set<String>) {
        let sentence = raw.trimmed
        guard !sentence.isEmpty else { return }

        let dedupeKey = sentence.lowercased()
        guard !seen.contains(dedupeKey) else { return }

        seen.insert(dedupeKey)
        result.append(sentence)
    }

    private static func stripListMarker(from line: String) -> String {
        let pattern = #"^\s*(?:[-*•]+|\d+[\.\)])\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
    }
    func filterCurrentItemsAfterGenerationIfNeeded() {
        guard showOnlyWithoutExamples else { return }
        items = items.filter { $0.examples.isEmpty }
    }

    func finalizeGenerationResult(createdWordCount: Int, createdExampleCount: Int, failures: [String]) {
        filterCurrentItemsAfterGenerationIfNeeded()
        progressText = "예문 생성 완료 words=\(createdWordCount) examples=\(createdExampleCount) failed=\(failures.count)"
        info = "예문 생성 완료 words=\(createdWordCount) examples=\(createdExampleCount)"
        isSentenceGeneratorPresented = false

        if !failures.isEmpty {
            error = failures.prefix(3).joined(separator: "\n")
        }
    }
}
