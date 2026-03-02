// ExampleDetailViewModel.swift

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class ExampleDetailViewModel: ObservableObject {
    private struct TokenDraft {
        let surface: String
        let phraseId: Int?
        let formId: Int?
    }

    let exampleId: Int
    let lesson: Lesson?
    let word: Vocabulary?

    @Published var example: Example?
    @Published var sentence: String = ""           // en
    @Published var translationText: String = ""   // excluding en
    @Published var isSaving = false
    @Published var isCreatingTokens = false
    @Published var isRecreatingTokens = false
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

    init(exampleId: Int, lesson: Lesson?, word: Vocabulary?) {
        self.exampleId = exampleId
        self.lesson = lesson
        self.word = word
    }

    func load() async {
        do {
            let ex = try await ExampleDataSource.shared.example(id: exampleId)
            example = ex
            await refreshTokenKoreanTranslations()
            sentence = ex.sentence
            let lines = ex.translations
                .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
                .map { "\($0.langCode): \($0.text)" }
                .joined(separator: "\n")
            translationText = lines

            if ex.tokens.isEmpty, !ex.sentence.trimmed.isEmpty {
                await createTokensFromSentence()
            }
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func save() async {
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "문장을 입력해 주세요."
            return
        }
        do {
            isSaving = true
            defer { isSaving = false }

            let payload = [ExampleTranslation].parse(from: translationText)

            let updated = try await ExampleDataSource.shared.updateExample(
                id: exampleId,
                sentence: sentence.trimmed,
                translations: payload
            )
            example = updated
            await refreshTokenKoreanTranslations()
            //info = "저장되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func createTokensFromSentence() async {
        guard let ex = example else { return }
        guard ex.tokens.isEmpty else { return }

        let rawParts = sentence.trimmed.tokenize()
        let mergedDrafts = await mergeTokensWithPhrases(rawParts)
        let drafts = await fillFormIds(in: mergedDrafts)
        guard !drafts.isEmpty else {
            error = "토큰화할 문장이 없습니다."
            return
        }

        do {
            isCreatingTokens = true
            defer { isCreatingTokens = false }

            for (idx, draft) in drafts.enumerated() {
                _ = try await SentenceTokenDataSource.shared.createSentenceToken(
                    exampleId: ex.id,
                    tokenIndex: idx,
                    surface: draft.surface,
                    phraseId: draft.phraseId,
                    formId: draft.formId
                )
            }

            let refreshed = try await ExampleDataSource.shared.example(id: ex.id)
            example = refreshed
            await refreshTokenKoreanTranslations()
            info = "토큰 \(drafts.count)개가 생성되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func mergeTokensWithPhrases(_ tokens: [String]) async -> [TokenDraft] {
        let queryTokens = Array(
            Set(
                tokens
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !punctuationSet.contains($0) }
                    .map { $0.lowercased() }
            )
        )
        guard !queryTokens.isEmpty else {
            return tokens.map { TokenDraft(surface: $0, phraseId: nil, formId: nil) }
        }

        var phraseById: [Int: PhraseRead] = [:]
        for token in queryTokens {
            if let rows = try? await PhraseDataSource.shared.listPhrases(q: token, limit: 200) {
                for row in rows {
                    phraseById[row.id] = row
                }
            }
        }

        let phrasePatterns: [(id: Int, tokens: [String])] = phraseById.values
            .map { (id: $0.id, tokens: $0.text.tokenize()) }
            .filter { $0.tokens.count >= 2 }
            .sorted { lhs, rhs in lhs.tokens.count > rhs.tokens.count }

        guard !phrasePatterns.isEmpty else {
            return tokens.map { TokenDraft(surface: $0, phraseId: nil, formId: nil) }
        }

        var merged: [TokenDraft] = []
        var i = 0
        while i < tokens.count {
            var matched: (id: Int, tokens: [String])? = nil

            for pattern in phrasePatterns {
                guard i + pattern.tokens.count <= tokens.count else { continue }

                let window = Array(tokens[i..<(i + pattern.tokens.count)])
                let isSame = zip(window, pattern.tokens).allSatisfy { a, b in
                    a.lowercased() == b.lowercased()
                }
                if isSame {
                    matched = (id: pattern.id, tokens: window)
                    break
                }
            }

            if let matched {
                merged.append(.init(surface: matched.tokens.joinTokens(), phraseId: matched.id, formId: nil))
                i += matched.tokens.count
            } else {
                merged.append(.init(surface: tokens[i], phraseId: nil, formId: nil))
                i += 1
            }
        }

        return merged
    }

    private func fillFormIds(in drafts: [TokenDraft]) async -> [TokenDraft] {
        var cache: [String: Int?] = [:]
        var output: [TokenDraft] = []
        output.reserveCapacity(drafts.count)

        for draft in drafts {
            let trimmed = draft.surface.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || punctuationSet.contains(trimmed) {
                output.append(draft)
                continue
            }

            let key = trimmed.lowercased()
            let formId: Int?
            if let cached = cache[key] {
                formId = cached
            } else {
                let rows = try? await WordFormDataSource.shared.listWordFormsByForm(form: trimmed, limit: 50)
                let exact = rows?.first(where: { $0.form.lowercased() == key })
                let picked = exact ?? rows?.first
                formId = picked?.id
                cache[key] = formId
            }

            output.append(.init(surface: draft.surface, phraseId: draft.phraseId, formId: formId))
        }

        return output
    }

    func recreateTokensFromSentence() async {
        guard let ex = example else { return }
        guard !isRecreatingTokens else { return }
        guard !sentence.trimmed.isEmpty else {
            error = "문장을 입력해 주세요."
            return
        }

        isRecreatingTokens = true
        defer { isRecreatingTokens = false }

        do {
            for token in ex.tokens {
                try await SentenceTokenDataSource.shared.deleteSentenceToken(id: token.id)
            }

            let refreshed = try await ExampleDataSource.shared.example(id: ex.id)
            example = refreshed
            await refreshTokenKoreanTranslations()

            await createTokensFromSentence()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func copyTokenSummary() async {
        
        guard let ex = example else { return }
        guard !isCopyingTokenSummary else { return }

        isCopyingTokenSummary = true
        defer { isCopyingTokenSummary = false }

        let sortedTokens = ex.tokens.sorted { $0.tokenIndex < $1.tokenIndex }
        let tokenLines = sortedTokens
            .filter { token in
                let trimmed = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                return token.phraseId == nil && !trimmed.isEmpty && !punctuationSet.contains(trimmed)
            }
            .map { token in
                "token_id:\(token.id) \(token.surface)"
            }
        let searchableTokens = sortedTokens
            .filter { token in
                let trimmed = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                return token.phraseId == nil && !trimmed.isEmpty && !punctuationSet.contains(trimmed)
            }

        var sensesById: [Int: (lemma: String, sense: WordSenseRead)] = [:]

        for token in searchableTokens {
            let surface = token.surface
            var senses = (try? await WordDataSource.shared.listWordSensesByLemma(lemma: surface, limit: 100)) ?? []
            var lemmaForOutput = surface

            if senses.isEmpty,
               let formId = token.formId,
               let form = try? await WordFormDataSource.shared.wordForm(id: formId),
               let word = try? await WordDataSource.shared.word(id: form.wordId) {
                senses = word.senses
                lemmaForOutput = word.lemma
            }

            for sense in senses {
                sensesById[sense.id] = (lemma: lemmaForOutput, sense: sense)
            }
        }

        let sensesLines = sensesById.values
            .sorted { $0.sense.id < $1.sense.id }
            .map { row in
                "sense_id:\(row.sense.id) \(row.lemma) (\(row.sense.senseCode)): \(row.sense.explain)"
            }

        let text = """
        sentence:
        \(ex.sentence)

        tokens:
        \(tokenLines.isEmpty ? "-" : tokenLines.joined(separator: "\n"))

        senses:
        \(sensesLines.isEmpty ? "-" : sensesLines.joined(separator: "\n"))
        """

        copyToPasteboard(text)

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

    func copyTokenTranslationSummary() {
        guard let ex = example else { return }

        let sortedTokens = ex.tokens.sorted { $0.tokenIndex < $1.tokenIndex }
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
        \(ex.sentence)

        tokens:
        \(tokenLines.isEmpty ? "-" : tokenLines.joined(separator: "\n"))
        """

        copyToPasteboard(text)
    }

    private func copyToPasteboard(_ text: String) {
#if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#elseif canImport(UIKit)
        UIPasteboard.general.string = text
#endif
    }

    func openSenseAssignSheet() {
        isShowingSenseAssignSheet = true
    }

    func openTokenTranslationSheet() {
        tokenTranslationText = ""
        isShowingTokenTranslationSheet = true
    }

    func applyTokenTranslations() async {
        guard !isApplyingTokenTranslations else { return }
        guard let ex = example else {
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

        let tokenById = Dictionary(uniqueKeysWithValues: ex.tokens.map { ($0.id, $0) })
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

            let refreshed = try await ExampleDataSource.shared.example(id: ex.id)
            example = refreshed
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

    func applySenseAssignments() async {
        guard let ex = example else { return }
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

        let tokenIds = Set(ex.tokens.map(\.id))
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
            for row in assignments { latestByTokenId[row.tokenId] = row.senseId }

            for (tokenId, senseId) in latestByTokenId {
                _ = try await SentenceTokenDataSource.shared.updateSentenceToken(
                    id: tokenId,
                    senseId: senseId
                )
                updated += 1
            }

            let refreshed = try await ExampleDataSource.shared.example(id: ex.id)
            example = refreshed
            await refreshTokenKoreanTranslations()
            isShowingSenseAssignSheet = false
            //info = "토큰 \(updated)개에 sense를 설정했습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

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

    private func refreshTokenKoreanTranslations() async {
        guard let tokens = example?.tokens, !tokens.isEmpty else {
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

    private func koreanText(from sense: WordSenseRead) -> String? {
        if let text = sense.translations.first(where: { isKorean($0.lang) })?.text.trimmed, !text.isEmpty {
            return text
        }
        return nil
    }

    private func koreanText(from phrase: PhraseRead) -> String? {
        if let text = phrase.translations.first(where: { isKorean($0.lang) })?.text.trimmed, !text.isEmpty {
            return text
        }
        return nil
    }

    private func isKorean(_ lang: String) -> Bool {
        let lowered = lang.lowercased()
        return lowered == "ko" || lowered.hasPrefix("ko-")
    }
}
