//
//  ExamplesSearchViewModel.swift
//  LessonClient
//
//  Created by 정영민 on 10/13/25.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class ExamplesSearchViewModel: ObservableObject {
    struct CopyableMessage: Identifiable {
        let id = UUID()
        let title: String
        let text: String
        let copyText: String
    }

    struct SentenceStatusPresentation: Identifiable {
        let text: String
        let isWarning: Bool

        var id: String { text }
    }

    private struct ExampleSentenceTarget {
        let example: Example
        let sentence: ExampleSentence

        var progressLabel: String {
            "example_id=\(example.id) sentence_id=\(sentence.id)"
        }
    }

    // Inputs
    @Published var q: String = ""
    @Published var levelText: String = ""   // numeric-only text
    @Published var unitText: String = ""    // numeric-only text
    @Published var showOnlyUnresolvableVocabulary: Bool = false
    @Published var showOnlyTokenNeedingExamples: Bool = false

    // State
    @Published var items: [Example] = []
    @Published var isLoading: Bool = false
    @Published var isRecreatingAllTokens: Bool = false
    @Published var isDeletingTokens: Bool = false
    @Published var isAddingSenses: Bool = false
    @Published var isCheckingStartEndIndices: Bool = false
    @Published var isRepairingStartEndIndices: Bool = false
    @Published var bulkProgressText: String?
    @Published var deleteProgressText: String?
    @Published var senseProgressText: String?
    @Published var startEndIndexProgressText: String?
    @Published var senseCodeBySenseId: [Int: String] = [:]
    @Published var senseCefrBySenseId: [Int: String] = [:]
    @Published var hasUnresolvableVocabularyByExampleId: [Int: Bool] = [:]
    @Published var unresolvableVocabularyWordByExampleId: [Int: String] = [:]
    @Published var hasMissingTokenVocabularyByExampleId: [Int: Bool] = [:]
    @Published var missingTokenVocabularyWordByExampleId: [Int: String] = [:]
    @Published var highestUnitByExampleId: [Int: Int] = [:]
    @Published var highestUnitWordByExampleId: [Int: String] = [:]
    @Published var needsStartEndIndexRepairByExampleId: [Int: Bool] = [:]
    @Published var copyableMessage: CopyableMessage?
    @Published var error: String?
    private let searchLimit: Int = 400
    private var searchGeneration: Int = 0
    private let sentenceUseCase = GenerateTokensUseCase.shared
    private let tokenRangesUseCase = TokenRangesUseCase.shared
    private let tokenVocabularyStatusLoader = ExampleTokenVocabularyStatusLoader()

    var displayItems: [Example] {
        items.filter { example in
            if showOnlyUnresolvableVocabulary &&
                hasUnresolvableVocabularyByExampleId[example.id] != true &&
                hasMissingTokenVocabularyByExampleId[example.id] != true {
                return false
            }
            if showOnlyTokenNeedingExamples &&
                !needsTokenRepair(for: example) {
                return false
            }
            return true
        }
    }

    var hasDeletableUnresolvableItems: Bool {
        return unresolvableVocabularyTargetItems(in: displayItems).contains { !$0.sentence.tokens.isEmpty }
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
            hasMissingTokenVocabularyByExampleId = [:]
            missingTokenVocabularyWordByExampleId = [:]
            highestUnitByExampleId = [:]
            highestUnitWordByExampleId = [:]
            needsStartEndIndexRepairByExampleId = [:]
            startEndIndexProgressText = nil

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
        let senseIds = Set(examples.flatMap { $0.allTokens.compactMap(\.senseId) })
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
        hasMissingTokenVocabularyByExampleId = batch.hasMissingTokenVocabularyByExampleId
        missingTokenVocabularyWordByExampleId = batch.missingTokenVocabularyWordByExampleId
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
        sentenceStatuses(for: example).first
    }

    func sentenceStatuses(for example: Example) -> [SentenceStatusPresentation] {
        var statuses: [SentenceStatusPresentation] = []

        if hasMissingTokenVocabularyByExampleId[example.id] == true {
            if let word = missingTokenVocabularyWordByExampleId[example.id], !word.isEmpty {
                statuses.append(.init(text: "vocabulary 없음 (\(word))", isWarning: true))
            } else {
                statuses.append(.init(text: "vocabulary 없음", isWarning: true))
            }
        }

        if hasUnresolvableVocabularyByExampleId[example.id] == true {
            if let word = unresolvableVocabularyWordByExampleId[example.id], !word.isEmpty {
                statuses.append(.init(text: "미학습 단어 포함 (\(word))", isWarning: true))
            } else {
                statuses.append(.init(text: "미학습 단어 포함", isWarning: true))
            }
        }

        if let highestUnit = highestUnitByExampleId[example.id] {
            if highestUnitExceedsExampleUnit(for: example),
               let word = highestUnitWordByExampleId[example.id],
               !word.isEmpty {
                statuses.append(.init(text: "최고 unit: \(highestUnit) (\(word))", isWarning: true))
            } else {
                statuses.append(.init(text: "최고 unit: \(highestUnit)", isWarning: false))
            }
        }

        return statuses
    }

    func needsTokenRepair(for example: Example) -> Bool {
        example.orderedExampleSentences.contains { needsTokenRepair(for: $0) }
    }

    func needsTokenRepair(for sentence: ExampleSentence) -> Bool {
        let checkTargets = sentence.tokens.filter { token in
            !punctuationSet.contains(token.surface)
        }
        let isTokenReady = !checkTargets.isEmpty && checkTargets.allSatisfy { token in
            token.senseId != nil || token.phraseId != nil
        }
        return !isTokenReady
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

    func checkStartEndIndices() async {
        guard !isCheckingStartEndIndices else { return }
        guard !isRepairingStartEndIndices else { return }

        let targetItems = sentenceTargets(in: displayItems)
        guard !targetItems.isEmpty else {
            needsStartEndIndexRepairByExampleId = [:]
            startEndIndexProgressText = "검사할 예문 문장이 없습니다."
            return
        }

        isCheckingStartEndIndices = true
        defer { isCheckingStartEndIndices = false }

        var checked: [Int: Bool] = [:]
        checked.reserveCapacity(displayItems.count)

        for (idx, target) in targetItems.enumerated() {
            startEndIndexProgressText = "start_end_index 검사 중... (\(idx + 1)/\(targetItems.count)) \(target.progressLabel)"
            let needsRepair = startEndIndexIssue(for: target).needsRepair
            checked[target.example.id] = (checked[target.example.id] ?? false) || needsRepair
        }

        needsStartEndIndexRepairByExampleId = checked
        let needCount = targetItems.filter { startEndIndexIssue(for: $0).needsRepair }.count
        startEndIndexProgressText = "start_end_index 검사 완료 need=\(needCount) checked=\(targetItems.count)"
    }

    func repairStartEndIndices() async {
        guard !isRepairingStartEndIndices else { return }
        guard !isCheckingStartEndIndices else { return }
        guard !isRecreatingAllTokens else { return }
        guard !isDeletingTokens else { return }
        guard !isAddingSenses else { return }

        let targetItems = sentenceTargets(in: displayItems).filter { startEndIndexIssue(for: $0).needsRepair }
        guard !targetItems.isEmpty else {
            startEndIndexProgressText = "복구할 예문 문장이 없습니다."
            return
        }

        isRepairingStartEndIndices = true
        defer { isRepairingStartEndIndices = false }

        var successSentences = 0
        var recreatedSentences = 0
        var reindexedSentences = 0
        var updatedTokenCount = 0
        var failedRows: [String] = []

        for (idx, target) in targetItems.enumerated() {
            startEndIndexProgressText = "start_end_index 복구 중... (\(idx + 1)/\(targetItems.count)) \(target.progressLabel)"

            do {
                let detailVM = ExampleSentenceDetailViewModel(
                    exampleSentence: target.sentence,
                    lesson: nil,
                    word: nil
                )
                await detailVM.load()
                if let loadError = detailVM.error, !loadError.isEmpty {
                    failedRows.append("\(target.progressLabel) load: \(loadError)")
                    continue
                }

                let currentIssue = startEndIndexIssue(for: target)

                if currentIssue.requiresRecreation {
                    await detailVM.recreateAllTokensFromSentence()
                    if let recreateError = detailVM.error, !recreateError.isEmpty {
                        failedRows.append("\(target.progressLabel) recreate: \(recreateError)")
                        continue
                    }

                    if detailVM.displayTokens.contains(where: { $0.startIndex == nil || $0.endIndex == nil }) {
                        let updatedCount = try await replaceTokenRanges(
                            sentence: detailVM.sentence,
                            tokens: detailVM.displayTokens
                        )
                        updatedTokenCount += updatedCount
                    }

                    recreatedSentences += 1
                    successSentences += 1
                    continue
                }

                let updatedCount = try await replaceTokenRanges(
                    sentence: detailVM.sentence,
                    tokens: detailVM.displayTokens
                )

                updatedTokenCount += updatedCount
                reindexedSentences += 1
                successSentences += 1
            } catch {
                failedRows.append("\(target.progressLabel) repair: \((error as NSError).localizedDescription)")
            }
        }

        await search()
        await checkStartEndIndices()

        if failedRows.isEmpty {
            startEndIndexProgressText = "start_end_index 복구 완료 sentences=\(successSentences) reindexed=\(reindexedSentences) recreated=\(recreatedSentences) tokens=\(updatedTokenCount)"
            return
        }

        let preview = failedRows.prefix(3).joined(separator: "\n")
        startEndIndexProgressText = "start_end_index 복구 완료 sentences=\(successSentences) reindexed=\(reindexedSentences) recreated=\(recreatedSentences) tokens=\(updatedTokenCount) failed=\(failedRows.count)"
        error = """
start_end_index 복구 중 일부 실패:
\(preview)
"""
    }

    func recreateAllTokens() async {
        guard !isRecreatingAllTokens else { return }
        let targetItems = sentenceTargets(in: displayItems)
        guard !targetItems.isEmpty else {
            error = "재생성할 예문 문장이 없습니다."
            return
        }

        isRecreatingAllTokens = true
        defer { isRecreatingAllTokens = false }
        var successCount = 0
        var skippedByTokenReady = 0
        var failedRows: [String] = []

        for (idx, target) in targetItems.enumerated() {
            bulkProgressText = "전체 생성 중... (\(idx + 1)/\(targetItems.count)) \(target.progressLabel)"

            let detailVM = ExampleSentenceDetailViewModel(
                exampleSentence: target.sentence,
                lesson: nil,
                word: nil
            )
            await detailVM.load()
            if let loadError = detailVM.error, !loadError.isEmpty {
                failedRows.append("\(target.progressLabel) load: \(loadError)")
                continue
            }

            let phraseDrafts = try? await sentenceUseCase.buildTokenDrafts(from: detailVM.sentence)
            let hasPhraseDraft = phraseDrafts?.contains(where: { $0.phraseId != nil }) == true

            let checkTargets = detailVM.displayTokens.filter { token in
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

            if hasPhraseDraft {
                await detailVM.recreateAllTokensFromSentence()
            } else {
                await detailVM.recreateTokensFromSentence()
            }
            if let recreateError = detailVM.error, !recreateError.isEmpty {
                failedRows.append("\(target.progressLabel) recreate: \(recreateError)")
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
            deleteProgressText = "미학습 단어가 있는 예문 문장이 없습니다."
            return
        }

        isDeletingTokens = true
        defer { isDeletingTokens = false }

        var successSentences = 0
        var deletedTokenCount = 0
        var skippedSentences = 0
        var failedRows: [String] = []

        for (idx, target) in targetItems.enumerated() {
            deleteProgressText = "토큰 삭제 중... (\(idx + 1)/\(targetItems.count)) \(target.progressLabel)"

            do {
                for token in target.sentence.tokens {
                    try await SentenceTokenDataSource.shared.deleteSentenceToken(id: token.id)
                }
                deletedTokenCount += target.sentence.tokens.count
                successSentences += 1
            } catch {
                if target.sentence.tokens.isEmpty {
                    skippedSentences += 1
                } else {
                    failedRows.append("\(target.progressLabel) delete: \((error as NSError).localizedDescription)")
                }
            }
        }

        await search()

        if failedRows.isEmpty {
            deleteProgressText = "토큰 삭제 완료 sentences=\(successSentences) tokens=\(deletedTokenCount) skipped=\(skippedSentences)"
            return
        }

        let preview = failedRows.prefix(3).joined(separator: "\n")
        deleteProgressText = "토큰 삭제 완료 sentences=\(successSentences) tokens=\(deletedTokenCount) skipped=\(skippedSentences) failed=\(failedRows.count)"
        error = """
토큰 삭제 중 일부 실패:
\(preview)
"""
    }

    func addSensesForAllExamples() async {
        guard !isAddingSenses else { return }
        guard !isRecreatingAllTokens else { return }
        copyableMessage = nil
        let visibleItems = sentenceTargets(in: displayItems)
        guard !visibleItems.isEmpty else {
            error = "sense를 추가할 예문 문장이 없습니다."
            return
        }

        isAddingSenses = true
        defer { isAddingSenses = false }

        let targetItems = missingSenseTargetItems(in: displayItems)
        guard !targetItems.isEmpty else {
            senseProgressText = "sense가 비어 있는 token 예문 문장이 없습니다."
            return
        }
        let openAIClient = OpenAIClient()

        var successSentences = 0
        var updatedTokenCount = 0
        var emptySenseSentences = 0
        var skippedByExistingSense = 0
        var failedRows: [String] = []
        var failedSurfaces: [String] = []

        for (idx, target) in targetItems.enumerated() {
            senseProgressText = "sense 추가 중... (\(idx + 1)/\(targetItems.count)) \(target.progressLabel)"

            let detailVM = ExampleSentenceDetailViewModel(
                exampleSentence: target.sentence,
                lesson: nil,
                word: nil
            )
            await detailVM.load()
            if let loadError = detailVM.error, !loadError.isEmpty {
                let row = "\(target.progressLabel) load: \(loadError)"
                failedRows.append(row)
                if let surface = copyableFailedSurface(from: row) {
                    failedSurfaces.append(surface)
                }
                continue
            }

            let checkTargets = detailVM.displayTokens.filter { token in
                !punctuationSet.contains(token.surface)
            }
            let isTokenReady = !checkTargets.isEmpty && checkTargets.allSatisfy { token in
                token.senseId != nil
            }
            if isTokenReady {
                skippedByExistingSense += 1
                continue
            }

            guard let tokenLLMText = await detailVM.tokenLLMText(),
                  !tokenLLMText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                let llmTextError = detailVM.error?.trimmingCharacters(in: .whitespacesAndNewlines)
                let row = "\(target.progressLabel) tokenLLMText: \(llmTextError?.isEmpty == false ? llmTextError! : "empty")"
                failedRows.append(row)
                if let surface = copyableFailedSurface(from: row) {
                    failedSurfaces.append(surface)
                }
                continue
            }

            let prompt = Prompt.makeSentenceTokenSensePrompt(copyText: tokenLLMText)

            do {
                let result = try? await openAIClient.generateText(prompt: prompt)
                guard let result else {
                    emptySenseSentences += 1
                    continue
                }

                if result.range(of: #"sense_id\s*:\s*\d+"#, options: .regularExpression) == nil {
                    emptySenseSentences += 1
                    continue
                }

                let assignments = try detailVM.parseSenseAssignmentsText(result)
                var latestByTokenId: [Int: (token: String?, senseId: Int)] = [:]
                for assignment in assignments {
                    latestByTokenId[assignment.tokenId] = (assignment.token, assignment.senseId)
                }

                if latestByTokenId.isEmpty {
                    emptySenseSentences += 1
                    continue
                }

                var wordBySenseId: [Int: WordRead] = [:]
                var formIdByWordToken: [String: Int?] = [:]
                let tokenById = Dictionary(uniqueKeysWithValues: target.sentence.tokens.map { ($0.id, $0) })

                for (tokenId, assignment) in latestByTokenId {
                    let word: WordRead
                    if let cached = wordBySenseId[assignment.senseId] {
                        word = cached
                    } else {
                        let sense = try await WordDataSource.shared.wordSense(senseId: assignment.senseId)
                        let loadedWord = try await WordDataSource.shared.word(id: sense.wordId)
                        wordBySenseId[assignment.senseId] = loadedWord
                        word = loadedWord
                    }

                    let parsedToken = assignment.token?.trimmed
                    let resolvedToken = (parsedToken?.isEmpty == false ? parsedToken : nil) ?? tokenById[tokenId]?.surface.trimmed
                    let normalizedToken = resolvedToken?.normalizedApostrophe.lowercased()
                    let normalizedLemma = word.lemma.trimmed.normalizedApostrophe.lowercased()

                    let formId: Int?
                    if normalizedToken == nil || normalizedToken == normalizedLemma {
                        formId = nil
                    } else {
                        let formCacheKey = "\(word.id)|\(normalizedToken!)"
                        if let cached = formIdByWordToken[formCacheKey] {
                            formId = cached
                        } else {
                            let rows = try await WordFormDataSource.shared.listWordFormsByForm(
                                form: resolvedToken ?? "",
                                limit: 50
                            )
                            let matched = rows.first { row in
                                row.wordId == word.id &&
                                row.form.trimmed.normalizedApostrophe.lowercased() == normalizedToken
                            }
                            formId = matched?.id
                            formIdByWordToken[formCacheKey] = formId
                        }
                    }

                    _ = try await SentenceTokenDataSource.shared.updateSentenceToken(
                        id: tokenId,
                        wordId: word.id,
                        formId: formId,
                        senseId: assignment.senseId
                    )
                }

                updatedTokenCount += latestByTokenId.count
                successSentences += 1
            } catch {
                let row = "\(target.progressLabel) sense: \((error as NSError).localizedDescription)"
                failedRows.append(row)
                if let surface = copyableFailedSurface(from: row) {
                    failedSurfaces.append(surface)
                }
            }
        }

        await search()

        if failedRows.isEmpty {
            senseProgressText = "sense 추가 완료 sentences=\(successSentences) tokens=\(updatedTokenCount) empty=\(emptySenseSentences) skipped=\(skippedByExistingSense)"
            return
        }

        senseProgressText = "sense 추가 완료 sentences=\(successSentences) tokens=\(updatedTokenCount) empty=\(emptySenseSentences) skipped=\(skippedByExistingSense) failed=\(failedRows.count)"
        copyableMessage = .init(
            title: "sense 추가 실패 목록",
            text: failedRows.joined(separator: "\n"),
            copyText: joinedCopyableSurfaces(from: failedSurfaces)
        )
    }

    private func missingSenseTargetItems(in examples: [Example]) -> [ExampleSentenceTarget] {
        return sentenceTargets(in: examples).filter { target in
            let checkTargets = target.sentence.tokens.filter { token in
                !punctuationSet.contains(token.surface)
            }
            guard !checkTargets.isEmpty else { return false }
            return checkTargets.contains { token in
                token.senseId == nil
            }
        }
    }

    private func unresolvableVocabularyTargetItems(in examples: [Example]) -> [ExampleSentenceTarget] {
        return sentenceTargets(in: examples).filter { target in
            return target.sentence.tokens.contains { token in
                let surface = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                return !surface.isEmpty &&
                    !punctuationSet.contains(surface) &&
                    token.vocabulary == nil
            }
        }
    }

    func needsStartEndIndexRepair(for example: Example) -> Bool {
        needsStartEndIndexRepairByExampleId[example.id] == true
    }

    private func startEndIndexIssue(for target: ExampleSentenceTarget) -> (needsRepair: Bool, requiresRecreation: Bool) {
        if target.sentence.tokens.isEmpty {
            return (true, true)
        }

        let hasMissingRange = target.sentence.tokens.contains { token in
            token.startIndex == nil || token.endIndex == nil
        }

        do {
            _ = try tokenRangesUseCase.buildTokenRangeUpdates(
                sentence: target.sentence.text,
                tokens: target.sentence.tokens
            )
        } catch {
            return (true, true)
        }

        return (hasMissingRange, false)
    }

    private func sentenceTargets(in examples: [Example]) -> [ExampleSentenceTarget] {
        examples.flatMap { example in
            example.orderedExampleSentences.map { sentence in
                ExampleSentenceTarget(example: example, sentence: sentence)
            }
        }
    }

    private func copyableFailedSurface(from row: String) -> String? {
        let pattern = #"surface=([^,]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(row.startIndex..<row.endIndex, in: row)
        guard
            let match = regex.firstMatch(in: row, range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: row)
        else {
            return nil
        }

        let surface = row[captureRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return surface.isEmpty ? nil : surface
    }

    private func joinedCopyableSurfaces(from surfaces: [String]) -> String {
        var seen: Set<String> = []
        let ordered = surfaces.compactMap { raw -> String? in
            let surface = raw.trimmed
            guard !surface.isEmpty else { return nil }

            let key = surface.normalizedApostrophe.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return surface
        }
        return ordered.joined(separator: ",")
    }

    func copyToPasteboard(_ text: String) {
#if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }

    /// full replace PUT을 사용해서 기존 token 필드를 보존한 채 range만 갱신합니다.
    private func replaceTokenRanges(sentence: String, tokens: [SentenceTokenRead]) async throws -> Int {
        let rangeUpdates = try tokenRangesUseCase.buildTokenRangeUpdates(
            sentence: sentence,
            tokens: tokens
        )
        let rangeByTokenId = Dictionary(uniqueKeysWithValues: rangeUpdates.map { ($0.tokenId, $0) })

        for token in tokens.sorted(by: { $0.tokenIndex < $1.tokenIndex }) {
            guard let range = rangeByTokenId[token.id] else { continue }
            _ = try await SentenceTokenDataSource.shared.replaceSentenceToken(
                id: token.id,
                exampleSentenceId: token.exampleSentenceId,
                tokenIndex: token.tokenIndex,
                surface: token.surface,
                phraseId: token.phraseId,
                wordId: token.wordId ?? token.sense?.wordId,
                formId: token.formId,
                senseId: token.senseId,
                pos: token.pos,
                startIndex: range.startIndex,
                endIndex: range.endIndex
            )
        }

        return rangeUpdates.count
    }
}
