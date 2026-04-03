// ExampleSentenceDetailViewModel.swift

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class ExampleSentenceDetailViewModel: ObservableObject {
    let exampleSentence: ExampleSentence
    let lesson: Lesson?
    let word: Vocabulary?

    @Published var example: Example?
    @Published var selectedExampleSentence: ExampleSentence?
    @Published var sentence: String = ""           // en
    @Published var translationText: String = ""   // excluding en
    @Published var isSaving = false
    @Published var isCreatingTokens = false
    @Published var isRecreatingTokens = false
    @Published var isDeletingTokens = false
    @Published var isCopyingTokenSummary = false
    @Published var isShowingSenseAssignSheet = false
    @Published var senseAssignText: String = ""
    @Published var isApplyingSenseAssign = false
    @Published var isShowingTokenTranslationSheet = false
    @Published var tokenTranslationText: String = ""
    @Published var isApplyingTokenTranslations = false
    @Published var tokenKoreanById: [Int: String] = [:]
    @Published var error: String?
    @Published var info: String?
    
    private let sentenceUseCase = GenerateTokensUseCase.shared
    private let tokenRangesUseCase = TokenRangesUseCase.shared
    private let buildTokenLLMTextUseCase = BuildTokenLLMTextUseCase.shared

    /// 뷰모델의 대상 예문/문맥 정보를 설정합니다.
    init(exampleSentence: ExampleSentence, lesson: Lesson?, word: Vocabulary?) {
        self.exampleSentence = exampleSentence
        self.lesson = lesson
        self.word = word
        self.selectedExampleSentence = exampleSentence
    }

    var displayTokens: [SentenceTokenRead] {
        selectedExampleSentence?.tokens ?? example.map(tokens(in:)) ?? []
    }

    var displayTranslations: [ExampleSentenceTranslation] {
        selectedExampleSentence?.translations ?? example.map(translations(in:)) ?? []
    }

    var displayExample: Example? {
        guard let example else { return nil }
        guard let selectedExampleSentence else { return example }

        return Example(
            id: example.id,
            createdAt: example.createdAt,
            isActive: example.isActive,
            tokensNeedFix: example.tokensNeedFix,
            vocabularyId: example.vocabularyId,
            phraseId: example.phraseId,
            vocabularyText: example.vocabularyText,
            phraseText: example.phraseText,
            unit: example.unit,
            exampleSentences: example.exampleSentences,
            exercises: selectedExampleSentence.exercises
        )
    }

    var canEditSentence: Bool {
        // ExampleSentence 단건 API가 있으므로 현재 선택 문장을 그대로 편집합니다.
        true
    }

    /// 예문 상세를 조회하고 화면 편집 상태를 초기화합니다.
    func load() async {
        do {
            let ex = try await ExampleDataSource.shared.example(id: exampleSentence.exampleId)
            example = ex
            selectedExampleSentence = resolvedExampleSentence(in: ex)
            // 선택된 ExampleSentence를 기준으로 편집 상태를 맞춥니다.
            sentence = selectedExampleSentence?.text ?? exampleSentence.text
            let lines = displayTranslations
                .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
                .map { "\($0.langCode): \($0.text)" }
                .joined(separator: "\n")
            translationText = lines
            await refreshTokenKoreanTranslations()

            if displayTokens.isEmpty, !sentence.trimmed.isEmpty {
                await createTokensFromSentence()
            }
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 현재 입력된 문장/번역을 예문에 저장합니다.
    func save() async {
        let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSentence.isEmpty else {
            error = "문장을 입력해 주세요."
            return
        }
        guard let activeExampleSentenceId else {
            error = "example_sentence를 찾을 수 없습니다."
            return
        }
        do {
            isSaving = true
            defer { isSaving = false }

            let payload = [ExampleSentenceTranslation].parse(from: translationText)

            // 문장과 번역은 example_sentence 단건 기준으로 저장합니다.
            let updatedSentence = try await ExampleSentenceDataSource.shared.updateExampleSentence(
                id: activeExampleSentenceId,
                payload: ExampleSentenceUpdate(
                    text: trimmedSentence,
                    translations: payload
                )
            )
            let updatedExample = try await ExampleDataSource.shared.example(id: updatedSentence.exampleId)
            example = updatedExample
            selectedExampleSentence = updatedExample.exampleSentences.first(where: { $0.id == updatedSentence.id }) ?? resolvedExampleSentence(in: updatedExample)
            sentence = selectedExampleSentence?.text ?? updatedSentence.text
            await refreshTokenKoreanTranslations()
            //info = "저장되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 문장을 기준으로 토큰을 새로 생성합니다.
    func createTokensFromSentence() async {
        guard example != nil else { return }
        guard displayTokens.isEmpty else { return }
        guard let activeExampleSentenceId else {
            error = "example_sentence를 찾을 수 없습니다."
            return
        }

        do {
            isCreatingTokens = true
            defer { isCreatingTokens = false }

            let created = try await sentenceUseCase.createTokensFromSentence(
                exampleSentenceId: activeExampleSentenceId,
                sentence: sentence
            )

            let refreshed = try await ExampleDataSource.shared.example(id: exampleSentence.exampleId)
            example = refreshed
            selectedExampleSentence = resolvedExampleSentence(in: refreshed)
            await refreshTokenKoreanTranslations()
            info = "토큰 \(created.count)개가 생성되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 기존 토큰을 문장 기준으로 다시 정렬/치환합니다.
    func recreateTokensFromSentence() async {
        guard example != nil else { return }
        guard !isRecreatingTokens else { return }
        guard !sentence.trimmed.isEmpty else {
            error = "문장을 입력해 주세요."
            return
        }

        isRecreatingTokens = true
        defer { isRecreatingTokens = false }

        do {
            if displayTokens.isEmpty {
                await createTokensFromSentence()
                return
            }
            guard let activeExampleSentenceId else {
                error = "example_sentence를 찾을 수 없습니다."
                return
            }

            let drafts = try await sentenceUseCase.buildTokenDrafts(from: sentence)
            let rangeDrafts = try tokenRangesUseCase.buildTokenRanges(
                from: sentence,
                surfaces: drafts.map(\.surface)
            )

            let existing = displayTokens.sorted(by: { $0.tokenIndex < $1.tokenIndex })
            let updateCount = min(existing.count, drafts.count)

            var updatedCount = 0

            if updateCount > 0 {
                for idx in 0..<updateCount {
                    let token = existing[idx]
                    let draft = drafts[idx]
                    let rangeDraft = rangeDrafts[idx]
                    _ = try await SentenceTokenDataSource.shared.replaceSentenceToken(
                        id: token.id,
                        exampleSentenceId: activeExampleSentenceId,
                        tokenIndex: idx,
                        surface: draft.surface,
                        phraseId: token.phraseId ?? draft.phraseId,
                        wordId: nil,
                        formId: token.formId ?? draft.formId,
                        senseId: token.senseId,
                        pos: nil,
                        startIndex: rangeDraft.startIndex,
                        endIndex: rangeDraft.endIndex
                    )
                    updatedCount += 1
                }
            }

            let refreshed = try await ExampleDataSource.shared.example(id: exampleSentence.exampleId)
            example = refreshed
            selectedExampleSentence = resolvedExampleSentence(in: refreshed)
            await refreshTokenKoreanTranslations()
            let untouchedExisting = max(existing.count - updateCount, 0)
            let ignoredDrafts = max(drafts.count - updateCount, 0)
            info = "토큰 갱신 완료 (updated=\(updatedCount), untouched=\(untouchedExisting), ignored=\(ignoredDrafts))"
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 기존 토큰을 모두 삭제한 뒤 phrase 없이 전체 재생성합니다.
    func recreateTokensWithoutPhrases() async {
        await recreateAllTokensFromSentence(includePhrases: false)
    }

    /// 기존 토큰을 모두 삭제한 뒤 문장 기준으로 전체 재생성합니다.
    func recreateAllTokensFromSentence(includePhrases: Bool = true) async {
        guard example != nil else { return }
        guard !isRecreatingTokens else { return }
        guard !sentence.trimmed.isEmpty else {
            error = "문장을 입력해 주세요."
            return
        }
        guard let activeExampleSentenceId else {
            error = "example_sentence를 찾을 수 없습니다."
            return
        }

        isRecreatingTokens = true
        defer { isRecreatingTokens = false }

        do {
            for token in displayTokens {
                try await SentenceTokenDataSource.shared.deleteSentenceToken(id: token.id)
            }

            let created = try await sentenceUseCase.createTokensFromSentence(
                exampleSentenceId: activeExampleSentenceId,
                sentence: sentence,
                includePhrases: includePhrases
            )

            let refreshed = try await ExampleDataSource.shared.example(id: exampleSentence.exampleId)
            example = refreshed
            selectedExampleSentence = resolvedExampleSentence(in: refreshed)
            await refreshTokenKoreanTranslations()
            if includePhrases {
                info = "구문 우선으로 토큰 \(created.count)개를 다시 생성했습니다."
            } else {
                info = "phrase 없이 토큰 \(created.count)개를 다시 생성했습니다."
            }
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 현재 예문의 모든 토큰을 삭제합니다.
    func deleteAllTokens() async {
        guard !isDeletingTokens else { return }
        guard example != nil else { return }
        guard !displayTokens.isEmpty else { return }
        let deletedCount = displayTokens.count

        isDeletingTokens = true
        defer { isDeletingTokens = false }

        do {
            for token in displayTokens {
                try await SentenceTokenDataSource.shared.deleteSentenceToken(id: token.id)
            }

            let refreshed = try await ExampleDataSource.shared.example(id: exampleSentence.exampleId)
            example = refreshed
            selectedExampleSentence = resolvedExampleSentence(in: refreshed)
            await refreshTokenKoreanTranslations()
            info = "토큰 \(deletedCount)개가 삭제되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 전체 복사
    func copyTokenLLMText() async {
        guard let text = await tokenLLMText() else { return }
        copyToPasteboard(text)
    }
    
    func tokenLLMText() async -> String? {
        guard let currentSentence = displayExampleSentence else { return nil }
        guard !isCopyingTokenSummary else { return nil }

        isCopyingTokenSummary = true
        defer { isCopyingTokenSummary = false }

        do {
            let text = try await makeTokenLLMText(exampleSentence: currentSentence)
            return text
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// 토큰/센스 LLM 입력 문자열을 생성합니다.
    private func makeTokenLLMText(exampleSentence: ExampleSentence) async throws -> String {
        try await buildTokenLLMTextUseCase.build(exampleSentence: exampleSentence)

//        let instruction = """
//
//        입력한 tokens들이 문장에서 해당되는 senseid를 출력해줘.
//        출력방식:
//        token:
//        token_id:
//        sense_id:
//        """
//        let prompt = text + instruction
//
//        do {
//            let result = try await OpenAIClient().generateText(prompt: prompt)
//            if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
//                senseAssignText = result.trimmingCharacters(in: .whitespacesAndNewlines)
//                isShowingSenseAssignSheet = true
//            }
//        } catch {
//            self.error = (error as NSError).localizedDescription
//        }
    }

    /// 외부 입력 텍스트를 token_id/sense_id 쌍으로 파싱합니다.
    func parseSenseAssignmentsText(_ raw: String) throws -> [(tokenId: Int, senseId: Int)] {
        try parseSenseAssignments(from: raw)
    }

    /// 토큰 번역 작업용 요약 텍스트를 클립보드에 복사합니다.
    func copyTokenTranslationSummary() {
        guard let currentSentence = displayExampleSentence else { return }

        let sortedTokens = currentSentence.tokens.sorted { $0.tokenIndex < $1.tokenIndex }
        let tokenLines = sortedTokens
            .filter { token in
                let trimmed = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                return token.phraseId == nil && !trimmed.isEmpty && !punctuationSet.contains(trimmed)
            }
            .map { token in
                "token_id:\(token.id) \(token.surface)"
            }

        let text = """
        sentence:
        \(currentSentence.text)

        tokens:
        \(tokenLines.isEmpty ? "-" : tokenLines.joined(separator: "\n"))
        """

        copyToPasteboard(text)
    }

    /// 문자열을 플랫폼별 클립보드에 복사합니다.
    private func copyToPasteboard(_ text: String) {
#if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#elseif canImport(UIKit)
        UIPasteboard.general.string = text
#endif
    }

    /// sense 일괄 지정 시트를 엽니다.
    func openSenseAssignSheet() {
        isShowingSenseAssignSheet = true
    }

    /// 토큰 번역 일괄 입력 시트를 엽니다.
    func openTokenTranslationSheet() {
        tokenTranslationText = ""
        isShowingTokenTranslationSheet = true
    }

    /// 입력된 토큰 번역을 파싱해 서버에 반영합니다.
    func applyTokenTranslations() async {
        guard !isApplyingTokenTranslations else { return }
        guard displayExample != nil else {
            error = "대상 예문을 찾을 수 없습니다."
            return
        }

        let assignments: [(tokenId: Int, translations: [String: String])]
        do {
            assignments = try parseTokenTranslations(from: tokenTranslationText)
        } catch {
            self.error = error.localizedDescription
            return
        }

        guard !assignments.isEmpty else {
            error = "적용할 번역이 없습니다."
            return
        }

        let tokenById = Dictionary(uniqueKeysWithValues: displayTokens.map { ($0.id, $0) })
        var unresolvedTokenIds: [Int] = []

        isApplyingTokenTranslations = true
        defer { isApplyingTokenTranslations = false }

        do {
            for row in assignments {
                guard tokenById[row.tokenId] != nil else {
                    unresolvedTokenIds.append(row.tokenId)
                    continue
                }

                for (lang, text) in row.translations where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    _ = try await SentenceTokenDataSource.shared.upsertSentenceTokenTranslation(
                        tokenId: row.tokenId,
                        lang: lang,
                        text: text
                    )
                }
            }

            let refreshed = try await ExampleDataSource.shared.example(id: exampleSentence.exampleId)
            example = refreshed
            selectedExampleSentence = resolvedExampleSentence(in: refreshed)
            await refreshTokenKoreanTranslations()
            isShowingTokenTranslationSheet = false
            if unresolvedTokenIds.isEmpty {
                info = "토큰 번역이 반영되었습니다."
            } else {
                info = "일부 token_id를 찾지 못해 제외되었습니다: \(Array(Set(unresolvedTokenIds)).sorted().map(String.init).joined(separator: ", "))"
            }
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 입력된 sense 할당 정보를 토큰에 반영합니다.
    func applySenseAssignments() async {
        guard example != nil else { return }
        guard !isApplyingSenseAssign else { return }

        let assignments: [(tokenId: Int, senseId: Int)]
        do {
            assignments = try parseSenseAssignments(from: senseAssignText)
        } catch {
            self.error = error.localizedDescription
            return
        }

        guard !assignments.isEmpty else {
            error = "적용할 token_id/sense_id가 없습니다."
            return
        }

        let tokenIds = Set(displayTokens.map(\.id))
        let invalidIds = assignments.map(\.tokenId).filter { !tokenIds.contains($0) }
        if !invalidIds.isEmpty {
            error = "존재하지 않는 token_id: \(Array(Set(invalidIds)).sorted().map(String.init).joined(separator: ", "))"
            return
        }

        isApplyingSenseAssign = true
        defer { isApplyingSenseAssign = false }

        do {
            var updated = 0
            var latestByTokenId: [Int: Int] = [:]
            var wordIdBySenseId: [Int: Int] = [:]
            for row in assignments { latestByTokenId[row.tokenId] = row.senseId }

            for (tokenId, senseId) in latestByTokenId {
                let wordId: Int
                if let cached = wordIdBySenseId[senseId] {
                    wordId = cached
                } else {
                    let sense = try await WordDataSource.shared.wordSense(senseId: senseId)
                    wordId = sense.wordId
                    wordIdBySenseId[senseId] = wordId
                }

                _ = try await SentenceTokenDataSource.shared.updateSentenceToken(
                    id: tokenId,
                    wordId: wordId,
                    senseId: senseId
                )
                updated += 1
            }

            let refreshed = try await ExampleDataSource.shared.example(id: exampleSentence.exampleId)
            example = refreshed
            selectedExampleSentence = resolvedExampleSentence(in: refreshed)
            await refreshTokenKoreanTranslations()
            isShowingSenseAssignSheet = false
            //info = "토큰 \(updated)개에 sense를 설정했습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// token_id/sense_id 텍스트 블록을 파싱합니다.
    private func parseSenseAssignments(from raw: String) throws -> [(tokenId: Int, senseId: Int)] {
        enum ParseError: LocalizedError {
            case invalidLine(String)
            case missingPair
            case invalidNumber(String)

            var errorDescription: String? {
                switch self {
                case .invalidLine(let line):
                    return "해석할 수 없는 라인: \(line)"
                case .missingPair:
                    return "token_id와 sense_id를 함께 입력해 주세요."
                case .invalidNumber(let value):
                    return "숫자 형식이 올바르지 않습니다: \(value)"
                }
            }
        }

        var rows: [(Int, Int)] = []
        var tokenId: Int?
        var senseId: Int?

        let lines = raw.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if let t = tokenId, let s = senseId { rows.append((t, s)) }
                tokenId = nil
                senseId = nil
                continue
            }

            guard let idx = trimmed.firstIndex(of: ":") else {
                throw ParseError.invalidLine(trimmed)
            }
            let key = trimmed[..<idx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = trimmed[trimmed.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "token" { continue }

            if key == "token_id" || key == "tokenid" {
                guard let v = Int(value), v >= 1 else { throw ParseError.invalidNumber(value) }
                tokenId = v
            } else if key == "sense_id" || key == "senseid" {
                if value.isEmpty { continue }
                guard let v = Int(value), v >= 1 else { throw ParseError.invalidNumber(value) }
                senseId = v
            } else {
                throw ParseError.invalidLine(trimmed)
            }
        }

        if let t = tokenId, let s = senseId { rows.append((t, s)) }
        if rows.isEmpty { throw ParseError.missingPair }
        return rows
    }

    /// token_id 기준 다국어 번역 텍스트를 파싱합니다.
    private func parseTokenTranslations(from raw: String) throws -> [(tokenId: Int, translations: [String: String])] {
        enum ParseError: LocalizedError {
            case invalidLine(String)
            case invalidTokenId(String)

            var errorDescription: String? {
                switch self {
                case .invalidLine(let line):
                    return "해석할 수 없는 라인: \(line)"
                case .invalidTokenId(let value):
                    return "token_id가 올바르지 않습니다: \(value)"
                }
            }
        }

        var output: [(tokenId: Int, translations: [String: String])] = []
        var tokenId: Int?
        var translations: [String: String] = [:]

        // 빈 줄 단위로 현재 토큰 번역 블록을 확정합니다.
        func flush() {
            if let tokenId, !translations.isEmpty {
                output.append((tokenId: tokenId, translations: translations))
            }
            tokenId = nil
            translations = [:]
        }

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                flush()
                continue
            }
            guard let idx = trimmed.firstIndex(of: ":") else {
                throw ParseError.invalidLine(trimmed)
            }
            let key = trimmed[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = trimmed[trimmed.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerKey = key.lowercased()

            if lowerKey == "token_id" || lowerKey == "tokenid" {
                guard let v = Int(value), v >= 1 else {
                    throw ParseError.invalidTokenId(value)
                }
                tokenId = v
            } else if lowerKey == "token" {
                continue
            } else if !value.isEmpty {
                translations[String(key)] = value
            }
        }
        flush()
        return output
    }

    /// 토큰별 한국어 뜻을 sense/phrase 기준으로 다시 계산합니다.
    private func refreshTokenKoreanTranslations() async {
        let tokens = displayTokens
        guard !tokens.isEmpty else {
            tokenKoreanById = [:]
            return
        }

        var koByTokenId: [Int: String] = [:]
        var senseByIdCache: [Int: WordSenseRead] = [:]
        var phraseCache: [Int: PhraseRead] = [:]

        for token in tokens.sorted(by: { $0.tokenIndex < $1.tokenIndex }) {
            let surface = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !surface.isEmpty, !punctuationSet.contains(surface) else { continue }

            if let senseId = token.senseId {
                let sense: WordSenseRead?
                if let cached = senseByIdCache[senseId] {
                    sense = cached
                } else {
                    let loaded = try? await WordDataSource.shared.wordSense(senseId: senseId)
                    if let loaded { senseByIdCache[senseId] = loaded }
                    sense = loaded
                }

                if let sense, let koText = koreanText(from: sense) {
                    koByTokenId[token.id] = koText
                    continue
                }
            }

            if let phraseId = token.phraseId {
                let phrase: PhraseRead?
                if let cached = phraseCache[phraseId] {
                    phrase = cached
                } else {
                    let loaded = try? await PhraseDataSource.shared.phrase(id: phraseId)
                    if let loaded { phraseCache[phraseId] = loaded }
                    phrase = loaded
                }

                if let phrase, let koText = koreanText(from: phrase) {
                    koByTokenId[token.id] = koText
                }
            }
        }

        tokenKoreanById = koByTokenId
    }

    private var activeExampleSentenceId: Int? {
        selectedExampleSentence?.id ?? exampleSentence.id
    }

    private var displayExampleSentence: ExampleSentence? {
        if let selectedExampleSentence {
            return selectedExampleSentence
        }
        if let example {
            return resolvedExampleSentence(in: example)
        }
        return exampleSentence
    }

    private func resolvedExampleSentence(in example: Example) -> ExampleSentence? {
        let targetId = selectedExampleSentence?.id ?? exampleSentence.id
        return example.exampleSentences.first(where: { $0.id == targetId })
    }

    private func translations(in example: Example) -> [ExampleSentenceTranslation] {
        resolvedExampleSentence(in: example)?.translations ?? exampleSentence.translations
    }

    private func tokens(in example: Example) -> [SentenceTokenRead] {
        resolvedExampleSentence(in: example)?.tokens ?? exampleSentence.tokens
    }

    private func displaySentenceText(example: Example) -> String {
        resolvedExampleSentence(in: example)?.text ?? exampleSentence.text
    }

    /// sense 번역 목록에서 한국어 텍스트를 추출합니다.
    private func koreanText(from sense: WordSenseRead) -> String? {
        if let text = sense.translations.first(where: { isKorean($0.lang) })?.text.trimmed, !text.isEmpty {
            return text
        }
        return nil
    }

    /// phrase 번역 목록에서 한국어 텍스트를 추출합니다.
    private func koreanText(from phrase: PhraseRead) -> String? {
        if let text = phrase.translations.first(where: { isKorean($0.lang) })?.text.trimmed, !text.isEmpty {
            return text
        }
        return nil
    }

    /// 언어 코드가 한국어 계열인지 판단합니다.
    private func isKorean(_ lang: String) -> Bool {
        let lowered = lang.lowercased()
        return lowered == "ko" || lowered.hasPrefix("ko-")
    }
}
