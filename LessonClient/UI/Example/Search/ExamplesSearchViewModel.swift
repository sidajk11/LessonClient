//
//  ExamplesSearchViewModel.swift
//  LessonClient
//
//  Created by 정영민 on 10/13/25.
//

import Foundation

@MainActor
final class ExamplesSearchViewModel: ObservableObject {
    struct SentenceStatusPresentation {
        let text: String
        let isWarning: Bool
    }

    // Inputs
    @Published var q: String = ""
    @Published var levelText: String = ""   // numeric-only text
    @Published var unitText: String = ""    // numeric-only text
    @Published var showOnlyUnresolvableVocabulary: Bool = false

    // State
    @Published var items: [Example] = []
    @Published var isLoading: Bool = false
    @Published var isRecreatingAllTokens: Bool = false
    @Published var isDeletingTokens: Bool = false
    @Published var isAddingSenses: Bool = false
    @Published var bulkProgressText: String?
    @Published var deleteProgressText: String?
    @Published var senseProgressText: String?
    @Published var senseCodeBySenseId: [Int: String] = [:]
    @Published var senseCefrBySenseId: [Int: String] = [:]
    @Published var hasUnresolvableVocabularyByExampleId: [Int: Bool] = [:]
    @Published var unresolvableVocabularyWordByExampleId: [Int: String] = [:]
    @Published var highestUnitByExampleId: [Int: Int] = [:]
    @Published var highestUnitWordByExampleId: [Int: String] = [:]
    @Published var error: String?
    private let searchLimit: Int = 400
    private var searchGeneration: Int = 0
    private let sentenceUseCase = SentenceUseCase.shared
    private let tokenVocabularyStatusLoader = ExampleTokenVocabularyStatusLoader()

    var displayItems: [Example] {
        guard showOnlyUnresolvableVocabulary else { return items }
        return items.filter { hasUnresolvableVocabularyByExampleId[$0.id] == true }
    }

    var hasDeletableUnresolvableItems: Bool {
        return unresolvableVocabularyTargetItems(in: displayItems).contains { !$0.tokens.isEmpty }
    }

    func search() async {
        let levelParam: Int? = levelText.isEmpty ? nil : Int(levelText)
        let unitParam: Int? = unitText.isEmpty ? nil : Int(unitText)

        if !levelText.isEmpty && levelParam == nil {
            error = "레벨은 숫자로 입력해 주세요."
            return
        }
        if !unitText.isEmpty && unitParam == nil {
            error = "Unit은 숫자로 입력해 주세요."
            return
        }

        error = nil
        searchGeneration += 1
        let generation = searchGeneration
        await fetchPage(level: levelParam, unit: unitParam, generation: generation)
    }

    private func fetchPage(level: Int?, unit: Int?, generation: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ExampleDataSource.shared.search(
                q: q,
                level: level,
                unit: unit,
                limit: searchLimit
            )

            guard generation == searchGeneration else { return }
            items = result
            sortItemsByUnitAscending()
            hasUnresolvableVocabularyByExampleId = [:]
            unresolvableVocabularyWordByExampleId = [:]
            highestUnitByExampleId = [:]
            highestUnitWordByExampleId = [:]

            guard !result.isEmpty else { return }

            Task { [weak self] in
                await self?.loadSenseCodes(for: result, generation: generation)
            }
            Task { [weak self] in
                await self?.loadSentenceStatuses(for: result, generation: generation)
            }
        } catch {
            guard generation == searchGeneration else { return }
            self.error = (error as NSError).localizedDescription
        }
    }

    private func loadSenseCodes(for examples: [Example], generation: Int) async {
        guard generation == searchGeneration else { return }
        let senseIds = Set(examples.flatMap { $0.tokens.compactMap(\.senseId) })
        guard !senseIds.isEmpty else { return }

        let missingIds = senseIds.filter {
            senseCodeBySenseId[$0] == nil || senseCefrBySenseId[$0] == nil
        }
        guard !missingIds.isEmpty else { return }

        let wordDS = WordDataSource.shared
        var loaded: [Int: String] = [:]
        var loadedCefr: [Int: String] = [:]

        await withTaskGroup(of: (Int, String?, String?).self) { group in
            for senseId in missingIds {
                group.addTask {
                    if Task.isCancelled { return (senseId, nil, nil) }
                    let sense = try? await wordDS.wordSense(senseId: senseId)
                    return (senseId, sense?.senseCode, sense?.cefr)
                }
            }

            for await (senseId, senseCode, cefr) in group {
                if Task.isCancelled { return }
                guard let senseCode, !senseCode.isEmpty else { continue }
                loaded[senseId] = senseCode
                if let cefr, !cefr.isEmpty {
                    loadedCefr[senseId] = cefr
                }
            }
        }

        if !loaded.isEmpty {
            guard generation == searchGeneration else { return }
            senseCodeBySenseId.merge(loaded) { _, new in new }
        }
        if !loadedCefr.isEmpty {
            guard generation == searchGeneration else { return }
            senseCefrBySenseId.merge(loadedCefr) { _, new in new }
        }
    }

    private func loadSentenceStatuses(for examples: [Example], generation: Int) async {
        guard generation == searchGeneration else { return }
        let batch = await tokenVocabularyStatusLoader.load(for: examples)

        guard generation == searchGeneration else { return }
        hasUnresolvableVocabularyByExampleId = batch.hasUnresolvableVocabularyByExampleId
        unresolvableVocabularyWordByExampleId = batch.unresolvableVocabularyWordByExampleId
        highestUnitByExampleId = batch.highestUnitByExampleId
        highestUnitWordByExampleId = batch.highestUnitWordByExampleId
    }

    func unitBadgeText(for example: Example) -> String {
        if let unit = example.unit {
            return "U\(unit)"
        }
        return "U-"
    }

    func sentenceStatus(for example: Example) -> SentenceStatusPresentation? {
        if hasUnresolvableVocabularyByExampleId[example.id] == true {
            if let word = unresolvableVocabularyWordByExampleId[example.id], !word.isEmpty {
                return .init(text: "미학습 단어 포함 (\(word))", isWarning: true)
            }
            return .init(text: "미학습 단어 포함", isWarning: true)
        }
        if let highestUnit = highestUnitByExampleId[example.id] {
            if highestUnitExceedsExampleUnit(for: example),
               let word = highestUnitWordByExampleId[example.id],
               !word.isEmpty {
                return .init(text: "최고 unit: \(highestUnit) (\(word))", isWarning: true)
            }
            return .init(text: "최고 unit: \(highestUnit)", isWarning: false)
        }
        return nil
    }

    private func highestUnitExceedsExampleUnit(for example: Example) -> Bool {
        guard let highestUnit = highestUnitByExampleId[example.id],
              let exampleUnit = example.unit else {
            return false
        }
        return highestUnit > exampleUnit
    }

    private func sortItemsByUnitAscending() {
        items.sort { lhs, rhs in
            let lhsUnit = lhs.unit ?? Int.max
            let rhsUnit = rhs.unit ?? Int.max

            if lhsUnit != rhsUnit {
                return lhsUnit < rhsUnit
            }
            return lhs.id < rhs.id
        }
    }

    func recreateAllTokens() async {
        guard !isRecreatingAllTokens else { return }
        let targetItems = displayItems
        guard !targetItems.isEmpty else {
            error = "재생성할 예문이 없습니다."
            return
        }

        isRecreatingAllTokens = true
        defer { isRecreatingAllTokens = false }
        var successCount = 0
        var skippedByTokenReady = 0
        var failedRows: [String] = []

        for (idx, row) in targetItems.enumerated() {
            bulkProgressText = "전체 생성 중... (\(idx + 1)/\(targetItems.count)) example_id=\(row.id)"

            let detailVM = ExampleDetailViewModel(exampleId: row.id, lesson: nil, word: nil)
            await detailVM.load()
            if let loadError = detailVM.error, !loadError.isEmpty {
                failedRows.append("#\(row.id) load: \(loadError)")
                continue
            }

            let phraseDrafts = try? await sentenceUseCase.buildTokenDrafts(from: detailVM.sentence)
            let hasPhraseDraft = phraseDrafts?.contains(where: { $0.phraseId != nil }) == true

            if let tokens = detailVM.example?.tokens {
                let checkTargets = tokens.filter { token in
                    !punctuationSet.contains(token.surface)
                }
                let isTokenReady = !checkTargets.isEmpty &&
                    checkTargets.allSatisfy { token in
                        token.senseId != nil || token.phraseId != nil
                }
                if isTokenReady {
                    skippedByTokenReady += 1
                    continue
                }
            }

            if hasPhraseDraft {
                await detailVM.recreateAllTokensFromSentence()
            } else {
                await detailVM.recreateTokensFromSentence()
            }
            if let recreateError = detailVM.error, !recreateError.isEmpty {
                failedRows.append("#\(row.id) recreate: \(recreateError)")
                continue
            }

            successCount += 1
        }

        await search()

        if failedRows.isEmpty {
            bulkProgressText = "전체 생성 완료 success=\(successCount) skipped=\(skippedByTokenReady)"
            return
        }

        let preview = failedRows.prefix(3).joined(separator: "\n")
        bulkProgressText = "전체 생성 완료 success=\(successCount) skipped=\(skippedByTokenReady) failed=\(failedRows.count)"
        error = """
전체 생성 중 일부 실패:
\(preview)
"""
    }

    func deleteTokensForExamplesWithUnresolvableVocabulary() async {
        guard !isDeletingTokens else { return }
        guard !isRecreatingAllTokens else { return }
        guard !isAddingSenses else { return }

        let targetItems = unresolvableVocabularyTargetItems(in: displayItems)
        guard !targetItems.isEmpty else {
            deleteProgressText = "미학습 단어가 있는 예문이 없습니다."
            return
        }

        isDeletingTokens = true
        defer { isDeletingTokens = false }

        var successExamples = 0
        var deletedTokenCount = 0
        var skippedExamples = 0
        var failedRows: [String] = []

        for (idx, row) in targetItems.enumerated() {
            deleteProgressText = "토큰 삭제 중... (\(idx + 1)/\(targetItems.count)) example_id=\(row.id)"

            do {
                // 삭제 대상은 현재 예문에 달린 모든 token입니다.
                for token in row.tokens {
                    try await SentenceTokenDataSource.shared.deleteSentenceToken(id: token.id)
                }
                deletedTokenCount += row.tokens.count
                successExamples += 1
            } catch {
                if row.tokens.isEmpty {
                    skippedExamples += 1
                } else {
                    failedRows.append("#\(row.id) delete: \((error as NSError).localizedDescription)")
                }
            }
        }

        await search()

        if failedRows.isEmpty {
            deleteProgressText = "토큰 삭제 완료 examples=\(successExamples) tokens=\(deletedTokenCount) skipped=\(skippedExamples)"
            return
        }

        let preview = failedRows.prefix(3).joined(separator: "\n")
        deleteProgressText = "토큰 삭제 완료 examples=\(successExamples) tokens=\(deletedTokenCount) skipped=\(skippedExamples) failed=\(failedRows.count)"
        error = """
토큰 삭제 중 일부 실패:
\(preview)
"""
    }

    func addSensesForAllExamples() async {
        guard !isAddingSenses else { return }
        guard !isRecreatingAllTokens else { return }
        let visibleItems = displayItems
        guard !visibleItems.isEmpty else {
            error = "sense를 추가할 예문이 없습니다."
            return
        }

        isAddingSenses = true
        defer { isAddingSenses = false }

        let targetItems = missingSenseTargetItems(in: visibleItems)
        guard !targetItems.isEmpty else {
            senseProgressText = "sense가 비어 있는 token 예문이 없습니다."
            return
        }
        let openAIClient = OpenAIClient()

        var successExamples = 0
        var updatedTokenCount = 0
        var emptySenseExamples = 0
        var skippedByExistingSense = 0
        var failedRows: [String] = []

        for (idx, row) in targetItems.enumerated() {
            senseProgressText = "sense 추가 중... (\(idx + 1)/\(targetItems.count)) example_id=\(row.id)"

            let detailVM = ExampleDetailViewModel(exampleId: row.id, lesson: nil, word: nil)
            await detailVM.load()
            if let loadError = detailVM.error, !loadError.isEmpty {
                failedRows.append("#\(row.id) load: \(loadError)")
                continue
            }

            if let tokens = detailVM.example?.tokens {
                let checkTargets = tokens.filter { token in
                    !punctuationSet.contains(token.surface)
                }
                let isTokenReady = !checkTargets.isEmpty && checkTargets.allSatisfy { token in
                    token.senseId != nil
                }
                if isTokenReady {
                    skippedByExistingSense += 1
                    continue
                }
            }

            guard let tokenSummary = await detailVM.tokenSummary(),
                  !tokenSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                failedRows.append("#\(row.id) tokenSummary: empty")
                continue
            }

            let prompt = Prompt.makeSentenceTokenSensePrompt(copyText: tokenSummary)

            do {
                let result = try? await openAIClient.generateText(prompt: prompt)
                guard let result else {
                    emptySenseExamples += 1
                    continue
                }

                if result.range(of: #"sense_id\s*:\s*\d+"#, options: .regularExpression) == nil {
                    emptySenseExamples += 1
                    continue
                }

                let assignments = try detailVM.parseSenseAssignmentsText(result)
                var latestByTokenId: [Int: Int] = [:]
                for assignment in assignments {
                    latestByTokenId[assignment.tokenId] = assignment.senseId
                }

                if latestByTokenId.isEmpty {
                    emptySenseExamples += 1
                    continue
                }

                for (tokenId, senseId) in latestByTokenId {
                    _ = try await SentenceTokenDataSource.shared.updateSentenceToken(
                        id: tokenId,
                        senseId: senseId
                    )
                }

                updatedTokenCount += latestByTokenId.count
                successExamples += 1
            } catch {
                failedRows.append("#\(row.id) sense: \((error as NSError).localizedDescription)")
            }
        }

        await search()

        if failedRows.isEmpty {
            senseProgressText = "sense 추가 완료 examples=\(successExamples) tokens=\(updatedTokenCount) empty=\(emptySenseExamples) skipped=\(skippedByExistingSense)"
            return
        }

        let preview = failedRows.prefix(3).joined(separator: "\n")
        senseProgressText = "sense 추가 완료 examples=\(successExamples) tokens=\(updatedTokenCount) empty=\(emptySenseExamples) skipped=\(skippedByExistingSense) failed=\(failedRows.count)"
        error = """
sense 추가 중 일부 실패:
\(preview)
"""
    }

    private func missingSenseTargetItems(in examples: [Example]) -> [Example] {
        return examples.filter { example in
            let checkTargets = example.tokens.filter { token in
                !punctuationSet.contains(token.surface)
            }
            guard !checkTargets.isEmpty else { return false }
            return checkTargets.contains { token in
                token.senseId == nil
            }
        }
    }

    private func unresolvableVocabularyTargetItems(in examples: [Example]) -> [Example] {
        return examples.filter { example in
            // 상태 로더와 동일하게 vocabulary가 비어 있는 token을 미학습 단어로 봅니다.
            return example.tokens.contains { token in
                let surface = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                return !surface.isEmpty &&
                    !punctuationSet.contains(surface) &&
                    token.vocabulary == nil
            }
        }
    }
}
