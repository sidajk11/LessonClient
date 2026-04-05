//
//  AutoGenerateWordSensesUseCase.swift
//  LessonClient
//
//  Created by ym on 4/3/26.
//

import Foundation

@MainActor
final class AutoGenerateWordSensesUseCase {
    struct GeneratedFormRow {
        let word: String
        let form: String
        let formType: String?
    }

    struct SenseGenerationResult {
        var createdWords: Int = 0
        var createdSenses: Int = 0
        var createdForms: Int = 0
        var createdPhrases: Int = 0
        var skipped: Int = 0
        var failures: [String] = []
    }

    struct AutoGenerateResult {
        let lemmas: [String]
        let generation: SenseGenerationResult
    }

    enum AutoGenerateError: LocalizedError {
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

    static let shared = AutoGenerateWordSensesUseCase()

    private let wordDataSource = WordDataSource.shared
    private let formDataSource = WordFormDataSource.shared
    private let phraseDataSource = PhraseDataSource.shared
    private let exampleDataSource = ExampleDataSource.shared
    private let generateWordUseCase = GenerateWordUseCase.shared
    private let openAIClient = OpenAIClient()

    private init() {}
}

extension AutoGenerateWordSensesUseCase {
    // 입력 문자열에서 lemma를 추출한 뒤 sense 생성까지 한 번에 수행한다.
    func autoGenerateSenses(
        from rawInput: String,
        onProgress: (String) -> Void = { _ in }
    ) async throws -> AutoGenerateResult {
        var lemmas = try await normalizedLemmas(from: rawInput, onProgress: onProgress)
        if try await shouldIncludeRawInputAsIndependentWord(rawInput: rawInput, lemmas: lemmas, onProgress: onProgress) {
            lemmas.append(rawInput.trimmed)
        }
        
        let generation = try await generateSenses(
            for: lemmas,
            progressPrefix: "Sense 자동 생성 중...",
            onProgress: onProgress
        )
        return AutoGenerateResult(lemmas: lemmas, generation: generation)
    }

    // word의 기존 form을 지우고 다시 생성한다.
    func regenerateForms(for word: WordRead) async throws -> Int {
        let lemma = word.lemma.trimmed
        guard shouldGenerateForms(for: lemma) else { return 0 }

        let existingForms = try await formDataSource.listWordForms(wordId: word.id, limit: 200, offset: 0)
        for form in existingForms {
            try await formDataSource.deleteWordForm(id: form.id)
        }

        return try await generateForms(for: lemma, word: word)
    }

    // 새 word에 필요한 form들을 생성한다.
    func generateForms(for lemma: String, word: WordRead) async throws -> Int {
        try await generateFormsInternal(for: lemma, word: word)
    }

    // lemma 목록을 순회하며 word, sense, form, phrase 생성을 처리한다.
    func generateSenses(
        for lemmas: [String],
        progressPrefix: String,
        onProgress: (String) -> Void = { _ in }
    ) async throws -> SenseGenerationResult {
        var result = SenseGenerationResult()

        // 일부 lemma에서 실패하더라도 전체 배치는 계속 진행한다.
        for (index, rawLemma) in lemmas.enumerated() {
            let lemma = rawLemma.trimmed
            guard !lemma.isEmpty else { continue }

            onProgress("\(progressPrefix) (\(index + 1)/\(lemmas.count)) \(lemma)")

            do {
                let existingSenses = try await serverSenses(lemma: lemma)
                if !existingSenses.isEmpty {
                    // 이미 sense가 있으면 form, phrase 같은 연결 데이터만 보강한다.
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

                // sense가 없으면 LLM으로 새 데이터를 만들고 headword도 검증한다.
                let generated = try await openAIClient.generateText(
                    prompt: Prompt.makeSensePrompt(for: lemma)
                )
                let parsed = try SenseBulkParser.parse(generated)
                let parsedHead = parsed.head.trimmed
                if !parsedHead.isEmpty, parsedHead.lowercased().normalizedApostrophe != lemma.lowercased().normalizedApostrophe {
                    throw AutoGenerateError.mismatchedHead(expected: lemma, actual: parsedHead)
                }

                let ensuredWord = try await ensureWord(for: lemma)
                if ensuredWord.wordWasCreated {
                    result.createdWords += 1
                }

                // sense를 먼저 저장한 뒤 form, phrase 같은 보조 데이터도 이어서 만든다.
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
                // 실패한 lemma는 메시지만 남기고 다음 항목으로 계속 진행한다.
                result.failures.append("\(lemma): \(error.localizedDescription)")
            }
        }

        return result
    }
}

private extension AutoGenerateWordSensesUseCase {
    // 원문 자체도 독립 단어 학습 대상인지 LLM으로 한 번 더 판단한다.
    func shouldIncludeRawInputAsIndependentWord(
        rawInput: String,
        lemmas: [String],
        onProgress: (String) -> Void
    ) async throws -> Bool {
        let trimmedInput = rawInput.trimmed
        guard !trimmedInput.isEmpty else { return false }

        let isSingleEntry = !trimmedInput.contains(",") && !trimmedInput.contains("\n")
        guard isSingleEntry else { return false }

        let normalizedInput = trimmedInput.normalizedApostrophe.lowercased()
        let alreadyIncluded = lemmas.contains {
            $0.normalizedApostrophe.lowercased() == normalizedInput
        }
        guard !alreadyIncluded else { return false }

        onProgress("독립 단어 여부 확인 중...")
        let response = try await openAIClient.generateText(
            prompt: Prompt.makeIndependentWordPrompts(for: trimmedInput)
        )
        return response.trimmed.uppercased().hasPrefix("Y")
    }

    // 자유 입력을 LLM에 보내 서버 처리용 lemma 목록으로 정규화한다.
    func normalizedLemmas(
        from rawInput: String,
        onProgress: (String) -> Void
    ) async throws -> [String] {
        let trimmedInput = rawInput.trimmed
        guard !trimmedInput.isEmpty else { throw AutoGenerateError.emptyInput }

        onProgress("lemma 추출 중...")
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

    // lemma 응답 문자열을 분리하고 중복 없는 목록으로 정리한다.
    func parseLemmaOutput(_ rawOutput: String) -> [String] {
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

    // LLM 응답 조각에서 불필요한 접두사와 기호를 제거한다.
    func sanitizeGeneratedLemma(_ token: String) -> String {
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

    // surface에 연결된 word를 찾고 없으면 새로 만든다.
    func ensureWord(for lemma: String) async throws -> (word: WordRead, wordWasCreated: Bool) {
        let result = try await generateWordUseCase.ensureWord(surface: lemma)
        return (result.word, result.wordWasCreated)
    }

    // 서버에 저장된 기존 sense 목록을 조회한다.
    func serverSenses(lemma: String) async throws -> [WordSenseRead] {
        do {
            return try await wordDataSource.listWordSensesByLemma(lemma: lemma, limit: 100)
        } catch APIClient.APIError.http(let statusCode, _) where statusCode == 404 {
            return []
        }
    }

    // 파싱된 sense 항목들을 서버 word sense와 예문으로 저장한다.
    func createSenses(from items: [SenseBulkParser.Item], for word: WordRead) async throws -> Int {
        var created = 0

        for (senseIndex, item) in items.enumerated() {
            let sense = try await wordDataSource.createWordSense(
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
                if let example = try? await exampleDataSource.createExample(vocabularyId: nil) {
                    _ = try? await ExampleSentenceDataSource.shared.createExampleSentence(
                        payload: ExampleSentenceCreate(
                            exampleId: example.id,
                            text: exampleText
                        )
                    )
                    _ = try? await wordDataSource.attachExampleToWordSense(
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

    // 단일 단어 lemma라면 form이 없을 때만 새 form들을 생성한다.
    func ensureFormsIfNeeded(for lemma: String, word: WordRead) async throws -> Int {
        guard shouldGenerateForms(for: lemma) else { return 0 }

        let existingForms = try await formDataSource.listWordForms(wordId: word.id, limit: 1, offset: 0)
        guard existingForms.isEmpty else { return 0 }

        return try await generateFormsInternal(for: lemma, word: word)
    }

    // form 프롬프트를 호출해 실제 form 레코드들을 생성한다.
    func generateFormsInternal(for lemma: String, word: WordRead) async throws -> Int {
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

            let derivedWordId = try? await wordDataSource.getWord(word: form).id

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

    // form 생성 응답을 word/form/form_type 행 목록으로 파싱한다.
    func parseFormOutput(_ rawOutput: String) -> [GeneratedFormRow] {
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

    // sense 항목의 번역을 이용해 phrase 생성 여부를 판단한다.
    func ensurePhraseIfNeeded(for lemma: String, items: [SenseBulkParser.Item]) async throws -> Bool {
        let translations = phraseTranslations(from: items.map(\.ko))
        return try await ensurePhraseIfNeeded(for: lemma, translations: translations)
    }

    // 기존 sense 번역을 이용해 phrase 생성 여부를 판단한다.
    func ensurePhraseIfNeeded(for lemma: String, senses: [WordSenseRead]) async throws -> Bool {
        let translations = phraseTranslations(
            from: senses.flatMap { sense in
                sense.translations
                    .filter { $0.lang.lowercased() == "ko" }
                    .map(\.text)
            }
        )
        return try await ensurePhraseIfNeeded(for: lemma, translations: translations)
    }

    // phrase 형태 lemma면 phrase를 만들거나 번역만 보강한다.
    func ensurePhraseIfNeeded(for lemma: String, translations: [PhraseTranslationSchema]?) async throws -> Bool {
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

        do {
            _ = try await phraseDataSource.createPhrase(text: lemma, translations: translations)
        } catch APIClient.APIError.http(let statusCode, _) where statusCode == 409 {
            return false
        }
        return true
    }

    // 같은 텍스트를 가진 phrase가 이미 있는지 조회한다.
    func findPhrase(text: String) async throws -> PhraseRead? {
        let trimmedText = text.trimmed
        guard !trimmedText.isEmpty else { return nil }

        let rows = try await phraseDataSource.listPhrases(q: trimmedText, limit: 20, offset: 0)
        return rows.first { $0.text.trimmed.caseInsensitiveCompare(trimmedText) == .orderedSame }
    }

    // 여러 번역 문자열을 phrase 저장용 한국어 번역 한 묶음으로 합친다.
    func phraseTranslations(from values: [String]) -> [PhraseTranslationSchema]? {
        var seen: Set<String> = []
        let uniqueValues = values
            .map(\.trimmed)
            .filter { !$0.isEmpty && $0 != "-" }
            .filter { seen.insert($0.lowercased()).inserted }

        guard !uniqueValues.isEmpty else { return nil }
        return [.init(lang: "ko", text: uniqueValues.joined(separator: " / "))]
    }

    // 공백이 포함된 lemma를 phrase 후보로 본다.
    func isPhraseLikeLemma(_ lemma: String) -> Bool {
        lemma.contains(" ")
    }

    // phrase가 아닌 경우에만 form 생성을 허용한다.
    func shouldGenerateForms(for lemma: String) -> Bool {
        !isPhraseLikeLemma(lemma)
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
