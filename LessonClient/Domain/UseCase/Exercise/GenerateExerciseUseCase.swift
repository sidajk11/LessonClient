//
//  GenerateExerciseUseCase.swift
//  LessonClient
//
//  Created by ym on 3/30/26.
//

import Foundation

// 예문 token을 바탕으로 combine/select 연습문제를 생성합니다.
final class GenerateExerciseUseCase {
    struct Draft {
        let type: ExerciseType
        let prompt: String
        let optionTexts: [String]
    }

    private enum GeneratorError: LocalizedError {
        case emptyVisibleTokens
        case staleTokens
        case targetTokenNotFound(String)
        case missingLessonUnit(String)
        case missingSelectDistractor

        var errorDescription: String? {
            switch self {
            case .emptyVisibleTokens:
                return "연습문제를 만들 수 있는 토큰이 없습니다."
            case .staleTokens:
                return "예문 토큰이 현재 문장과 맞지 않습니다. 토큰을 재생성한 뒤 다시 시도해 주세요."
            case .targetTokenNotFound(let text):
                return "'\(text)'에 해당하는 예문 토큰을 찾을 수 없습니다."
            case .missingLessonUnit(let text):
                return "'\(text)'의 lesson unit 정보를 찾을 수 없습니다."
            case .missingSelectDistractor:
                return "select 연습문제에 사용할 보기 후보가 없습니다."
            }
        }
    }

    static let shared = GenerateExerciseUseCase()

    private let exerciseDataSource = ExerciseDataSource.shared
    private let vocabularyDataSource = VocabularyDataSource.shared
    private let lessonDataSource = LessonDataSource.shared
    private let sentenceTokenDataSource = SentenceTokenDataSource.shared
    private let sentenceUseCase = GenerateTokensUseCase.shared
    private let tokenRangesUseCase = TokenRangesUseCase.shared

    private init() {}
}

extension GenerateExerciseUseCase {
    func autoGenerateMissingExercises(
        exampleSentence: ExampleSentence,
        targetVocabulary: Vocabulary?
    ) async throws -> [Exercise] {
        let existing = try await exerciseDataSource.list(exampleId: exampleSentence.exampleId)
            .filter { exercise in
                exercise.targetSentences.contains { $0.exampleSentenceId == exampleSentence.id }
            }
        var created: [Exercise] = []

        if !existing.contains(where: { $0.type == .combine }) {
            let draft = try await makeCombineDraft(exampleSentence: exampleSentence)
            let exercise = try await createExercise(exampleSentence: exampleSentence, draft: draft)
            created.append(exercise)
        }

        if !existing.contains(where: { $0.type == .select }),
           let targetVocabulary {
            let draft = try await makeSelectDraft(
                exampleSentence: exampleSentence,
                targetVocabulary: targetVocabulary
            )
            let exercise = try await createExercise(exampleSentence: exampleSentence, draft: draft)
            created.append(exercise)
        }

        return created
    }

    func makeCombineDraft(exampleSentence: ExampleSentence) async throws -> Draft {
        let tokens = try await tokens(for: exampleSentence)
        let visibleTokens = nonPunctuationTokens(from: tokens)
        guard !visibleTokens.isEmpty else {
            throw GeneratorError.emptyVisibleTokens
        }

        // 문장 내 실제 token 순서를 그대로 사용해서 조합형 문제를 만듭니다.
        let promptTokens = tokens.map { token in
            isPunctuation(token.surface) ? token.surface : "_"
        }
        return Draft(
            type: .combine,
            prompt: promptTokens.joinTokens(),
            optionTexts: visibleTokens.map(\.surface)
        )
    }

    func makeSelectDraft(
        exampleSentence: ExampleSentence,
        targetVocabulary: Vocabulary
    ) async throws -> Draft {
        let tokens = try await tokens(for: exampleSentence)
        let visibleTokens = nonPunctuationTokens(from: tokens)
        guard !visibleTokens.isEmpty else {
            throw GeneratorError.emptyVisibleTokens
        }

        let matchedTokens = visibleTokens.filter {
            matchesTargetVocabulary(token: $0, targetVocabulary: targetVocabulary)
        }
        guard let correctToken = matchedTokens.first else {
            throw GeneratorError.targetTokenNotFound(targetVocabulary.text)
        }

        let lessonUnit = try await lessonUnit(for: targetVocabulary)
        let distractor = try await selectDistractor(
            lessonUnit: lessonUnit,
            visibleTokens: visibleTokens,
            correctSurface: correctToken.surface
        )

        let matchedTokenIds = Set(matchedTokens.map(\.id))
        // target token과 연결된 위치만 "_"로 바꿔서 선택형 문제를 만듭니다.
        let promptTokens = tokens.map { token in
            matchedTokenIds.contains(token.id) ? "_" : token.surface
        }
        let prompt = promptTokens.joinTokens()
        guard prompt.contains("_") else {
            throw GeneratorError.targetTokenNotFound(targetVocabulary.text)
        }

        return Draft(
            type: .select,
            prompt: prompt,
            optionTexts: [correctToken.surface, distractor]
        )
    }

    // 화면에서 구성한 draft를 실제 exercise 생성으로 연결합니다.
    func createExercise(
        exampleSentence: ExampleSentence,
        draft: Draft
    ) async throws -> Exercise {
        let options = draft.optionTexts.map {
            let text = NL.lowercaseAvailable(sentence: exampleSentence.text, word: $0) ? $0.lowercased() : $0
            return ExerciseOptionUpdate.textOption(text)
        }

        let payload = ExerciseCreate(
            exampleId: exampleSentence.exampleId,
            targetSentenceIds: [exampleSentence.id],
            type: draft.type,
            prompt: draft.prompt,
            options: options,
            translations: [ExerciseTranslation(langCode: .enUS, question: nil)]
        )
        return try await exerciseDataSource.create(practice: payload)
    }
}

private extension GenerateExerciseUseCase {
    func tokens(for exampleSentence: ExampleSentence) async throws -> [SentenceTokenRead] {
        let localTokens = sortTokens(exampleSentence.tokens)
        if isUsable(tokens: localTokens, sentence: exampleSentence.text) {
            return localTokens
        }

        let remoteTokens = sortTokens(
            try await sentenceTokenDataSource.listSentenceTokens(
                exampleSentenceId: exampleSentence.id,
                limit: 200
            )
        )
        if isUsable(tokens: remoteTokens, sentence: exampleSentence.text) {
            return remoteTokens
        }

        // 토큰이 전혀 없을 때만 새로 생성해서 자동 생성 흐름을 이어갑니다.
        if localTokens.isEmpty && remoteTokens.isEmpty {
            let createdTokens = sortTokens(
                try await sentenceUseCase.createTokensFromSentence(
                    exampleSentenceId: exampleSentence.id,
                    sentence: exampleSentence.text
                )
            )
            if isUsable(tokens: createdTokens, sentence: exampleSentence.text) {
                return createdTokens
            }
        }

        throw GeneratorError.staleTokens
    }

    func sortTokens(_ tokens: [SentenceTokenRead]) -> [SentenceTokenRead] {
        tokens.sorted {
            if $0.tokenIndex == $1.tokenIndex {
                return $0.id < $1.id
            }
            return $0.tokenIndex < $1.tokenIndex
        }
    }

    func isUsable(tokens: [SentenceTokenRead], sentence: String) -> Bool {
        guard !tokens.isEmpty else { return false }
        let surfaces = tokens.map(\.surface)
        return (try? tokenRangesUseCase.buildTokenRanges(from: sentence, surfaces: surfaces)) != nil
    }

    func nonPunctuationTokens(from tokens: [SentenceTokenRead]) -> [SentenceTokenRead] {
        tokens.filter { !isPunctuation($0.surface) }
    }

    func isPunctuation(_ text: String) -> Bool {
        punctuationSet.contains(text)
    }

    func matchesTargetVocabulary(
        token: SentenceTokenRead,
        targetVocabulary: Vocabulary
    ) -> Bool {
        if let phraseId = targetVocabulary.phraseId,
           token.phraseId == phraseId {
            return true
        }
        if let senseId = targetVocabulary.senseId,
           token.senseId == senseId {
            return true
        }
        if let formId = targetVocabulary.formId,
           token.formId == formId {
            return true
        }
        if let wordId = targetVocabulary.wordId,
           token.wordId == wordId {
            return true
        }
        if token.vocabulary?.id == targetVocabulary.id {
            return true
        }

        let normalizedTarget = normalizedText(targetVocabulary.text)
        if let tokenVocabularyText = token.vocabulary?.text,
           normalizedText(tokenVocabularyText) == normalizedTarget {
            return true
        }

        if normalizedText(token.surface) == normalizedTarget {
            return true
        }

        return token.surface.isSameWord(word: targetVocabulary.text)
    }

    func lessonUnit(for targetVocabulary: Vocabulary) async throws -> Int {
        if let unit = targetVocabulary.unit {
            return unit
        }
        guard let lessonId = targetVocabulary.lessonId else {
            throw GeneratorError.missingLessonUnit(targetVocabulary.text)
        }
        let lesson = try await lessonDataSource.lesson(id: lessonId)
        return lesson.unit
    }

    func selectDistractor(
        lessonUnit: Int,
        visibleTokens: [SentenceTokenRead],
        correctSurface: String
    ) async throws -> String {
        let usedSurfaces = visibleTokens.map(\.surface)
        let candidates = try await vocabularyDataSource.wordsLessThan(unit: lessonUnit)
            .map(\.text)
            .filter { !$0.contains(" ") }
            .filter { candidate in
                !candidate.isSameWord(word: correctSurface)
            }
            .filter { candidate in
                !usedSurfaces.contains(where: { $0.isSameWord(word: candidate) })
            }

        guard let distractor = candidates.randomElement() else {
            throw GeneratorError.missingSelectDistractor
        }
        return distractor
    }

    func normalizedText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .normalizedApostrophe
            .lowercased()
    }
}
