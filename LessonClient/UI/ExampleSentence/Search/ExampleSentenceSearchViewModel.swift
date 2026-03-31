//
//  ExampleSentenceSearchViewModel.swift
//  LessonClient
//
//  Created by Codex on 3/30/26.
//

import Foundation

@MainActor
final class ExampleSentenceSearchViewModel: ObservableObject {
    struct Item: Identifiable {
        let example: Example
        let sentence: ExampleSentence

        var id: Int { sentence.id }
    }

    @Published var q: String = ""
    @Published var levelText: String = ""
    @Published var unitText: String = ""
    @Published var showOnlyMultiSentence: Bool = false

    @Published var items: [Item] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var senseCodeBySenseId: [Int: String] = [:]
    @Published var senseCefrBySenseId: [Int: String] = [:]
    @Published var deletingExerciseSentenceIds: Set<Int> = []
    @Published var generatingExerciseSentenceIds: Set<Int> = []

    private let searchLimit: Int = 400

    func sanitizeLevel(_ value: String) {
        levelText = value.filter(\.isNumber)
    }

    func sanitizeUnit(_ value: String) {
        unitText = value.filter(\.isNumber)
    }

    func search() async {
        let levelParam: Int? = levelText.isEmpty ? nil : Int(levelText)
        let unitParam: Int? = unitText.isEmpty ? nil : Int(unitText)
        let trimmedQuery = q.trimmingCharacters(in: .whitespacesAndNewlines)

        if !levelText.isEmpty && levelParam == nil {
            error = "레벨은 숫자로 입력해 주세요."
            return
        }
        if !unitText.isEmpty && unitParam == nil {
            error = "Unit은 숫자로 입력해 주세요."
            return
        }

        do {
            error = nil
            isLoading = true
            defer { isLoading = false }

            let sentences: [ExampleSentence]

            if showOnlyMultiSentence {
                // multi-sentence API를 우선 사용하고 검색어는 클라이언트에서 한 번 더 거릅니다.
                let multiSentenceRows = try await ExampleSentenceDataSource.shared.listMultiSentenceExampleSentences(
                    level: levelParam,
                    unit: unitParam,
                    limit: searchLimit,
                    offset: 0
                )
                if trimmedQuery.isEmpty {
                    sentences = multiSentenceRows
                } else {
                    let loweredQuery = trimmedQuery.lowercased()
                    sentences = multiSentenceRows.filter { sentence in
                        sentence.text.lowercased().contains(loweredQuery) ||
                        sentence.translations.contains { $0.text.lowercased().contains(loweredQuery) }
                    }
                }
            } else {
                sentences = try await ExampleSentenceDataSource.shared.searchExampleSentences(
                    q: trimmedQuery,
                    level: levelParam,
                    unit: unitParam,
                    limit: searchLimit
                )
            }

            let exampleIds = Array(Set(sentences.map(\.exampleId))).sorted()
            var exampleById: [Int: Example] = [:]

            for exampleId in exampleIds {
                // sentence 검색 결과에 포함된 example만 메타 정보 조회에 사용합니다.
                let example = try await ExampleDataSource.shared.example(id: exampleId)
                exampleById[exampleId] = example
            }

            // sentence 검색 결과에 맞는 example 컨텍스트를 붙여서 화면용 item을 만듭니다.
            items = sentences.compactMap { sentence in
                guard let example = exampleById[sentence.exampleId] else { return nil }
                let resolvedSentence = example.exampleSentences.first(where: { $0.id == sentence.id }) ?? sentence
                return Item(example: example, sentence: resolvedSentence)
            }
            .sorted { lhs, rhs in
                let lhsUnit = lhs.example.unit ?? Int.max
                let rhsUnit = rhs.example.unit ?? Int.max
                if lhsUnit != rhsUnit {
                    return lhsUnit < rhsUnit
                }
                if lhs.example.id != rhs.example.id {
                    return lhs.example.id < rhs.example.id
                }
                return lhs.sentence.order < rhs.sentence.order
            }

            await loadSenseCodes(for: items)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unitBadgeText(for example: Example) -> String {
        if let unit = example.unit {
            return "U\(unit)"
        }
        return "U-"
    }

    func isDeletingExercises(for sentenceId: Int) -> Bool {
        deletingExerciseSentenceIds.contains(sentenceId)
    }

    func isGeneratingExercises(for sentenceId: Int) -> Bool {
        generatingExerciseSentenceIds.contains(sentenceId)
    }

    func deleteExercises(for item: Item) async {
        guard !isDeletingExercises(for: item.sentence.id) else { return }

        deletingExerciseSentenceIds.insert(item.sentence.id)
        defer { deletingExerciseSentenceIds.remove(item.sentence.id) }

        do {
            // sentence에 연결된 exercise만 다시 조회해서 삭제합니다.
            let exercises = try await ExerciseDataSource.shared.list(exampleId: item.example.id)
                .filter { exercise in
                    exercise.targetSentences.contains { $0.exampleSentenceId == item.sentence.id }
                }

            for exercise in exercises {
                try await ExerciseDataSource.shared.delete(id: exercise.id)
            }

            try await refreshItem(exampleId: item.example.id, sentenceId: item.sentence.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func autoGenerateExercises(for item: Item) async {
        guard !isGeneratingExercises(for: item.sentence.id) else { return }

        generatingExerciseSentenceIds.insert(item.sentence.id)
        defer { generatingExerciseSentenceIds.remove(item.sentence.id) }

        do {
            let targetVocabulary: Vocabulary?
            if let vocabularyId = item.example.vocabularyId {
                // select 자동생성을 위해 target vocabulary를 보강합니다.
                targetVocabulary = try await VocabularyDataSource.shared.vocabulary(id: vocabularyId)
            } else {
                targetVocabulary = nil
            }

            _ = try await GenerateExerciseUseCase.shared.autoGenerateMissingExercises(
                exampleSentence: item.sentence,
                targetVocabulary: targetVocabulary
            )

            try await refreshItem(exampleId: item.example.id, sentenceId: item.sentence.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadSenseCodes(for items: [Item]) async {
        let senseIds = Set(items.flatMap { item in
            item.sentence.tokens.compactMap(\.senseId)
        })
        let missingIds = senseIds.filter {
            senseCodeBySenseId[$0] == nil || senseCefrBySenseId[$0] == nil
        }
        guard !missingIds.isEmpty else { return }

        var loadedCodes: [Int: String] = [:]
        var loadedCefr: [Int: String] = [:]

        for senseId in missingIds {
            if let sense = try? await WordDataSource.shared.wordSense(senseId: senseId) {
                loadedCodes[senseId] = sense.senseCode
                if let cefr = sense.cefr, !cefr.isEmpty {
                    loadedCefr[senseId] = cefr
                }
            }
        }

        senseCodeBySenseId.merge(loadedCodes) { _, new in new }
        senseCefrBySenseId.merge(loadedCefr) { _, new in new }
    }

    private func refreshItem(exampleId: Int, sentenceId: Int) async throws {
        // sentence 단건 응답이 tokens/exercises 최신 상태를 더 정확히 반영합니다.
        let refreshedSentence = try await ExampleSentenceDataSource.shared.exampleSentence(id: sentenceId)
        let refreshedExample = try await ExampleDataSource.shared.example(id: exampleId)

        guard refreshedExample.exampleSentences.contains(where: { $0.id == sentenceId }) else {
            items.removeAll { $0.sentence.id == sentenceId }
            return
        }

        let refreshedItem = Item(example: refreshedExample, sentence: refreshedSentence)
        if let index = items.firstIndex(where: { $0.sentence.id == sentenceId }) {
            items[index] = refreshedItem
        } else {
            items.append(refreshedItem)
        }
    }
}
