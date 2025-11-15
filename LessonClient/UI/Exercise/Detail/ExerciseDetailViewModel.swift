//
//  ExerciseDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import SwiftUI
import Combine

final class ExerciseDetailViewModel: ObservableObject {
    @Published var example: Example
    @Published var exercise: Exercise

    @Published var sentence: String = ""
    @Published var content: String = ""
    @Published var optionsText: String = ""

    // ✅ 더미 단어 관리 상태
    @Published var currentOptions: [String] = []  // 현재 보기(enUS)
    @Published var extraWords: [String] = []      // 추가 가능 단어
    @Published var isLoadingWords: Bool = false
    @Published var isSaving: Bool = false
    @Published var hasChanges: Bool = false

    @Published var isDeleting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showDeleteConfirm: Bool = false

    private var originalOptions: [String] = []
    private var wordsLearned: [Word] = []

    init(example: Example, exercise: Exercise) {
        self.example = example
        self.exercise = exercise

        if exercise.type == .combine {
            sentence = example.translations.text(langCode: .ko)
            content = exercise.translations.content(langCode: .enUS)
            optionsText = exercise.wordOptions.text(langCode: .enUS)
        } else if exercise.type == .select {
            sentence = example.translations.text(langCode: .ko)
            content = exercise.translations.content(langCode: .enUS)
            optionsText = exercise.wordOptions.text(langCode: .enUS)
        }

        // ✅ select 타입일 때 편집 데이터 준비
        if exercise.type == .select {
            let opts = Self.enOptions(from: exercise)
            self.currentOptions = opts
            self.originalOptions = opts
            Task { await loadExtraWords() }
        }
    }

    // MARK: - Helpers
    private static func enOptions(from exercise: Exercise) -> [String] {
        exercise.wordOptions.compactMap {
            $0.translations.first(where: { $0.langCode == .enUS })?.text
        }
    }

    private func recomputeExtraWords() {
        // learned - currentOptions (대소문자 무시)
        let learned = Set(wordsLearned.map { NL.lowercaseAvailable(sentence: "", word: $0.text) ? $0.text.lowercased() : $0.text })
        let current = Set(currentOptions.map { NL.lowercaseAvailable(sentence: "", word: $0) ? $0.lowercased() : $0 })
        let extra = Array(learned).subtractingWords(Array(current))
        // 보기 좋게 알파벳 정렬 (원하면 제거)
        self.extraWords = extra.sorted()
        // 변경 여부
        self.hasChanges = !equalsCI(lhs: currentOptions, rhs: originalOptions)
        // 표시용 텍스트 업데이트
        self.optionsText = currentOptions.joined(separator: ", ")
    }

    private func equalsCI(lhs: [String], rhs: [String]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0.lowercased() == $1.lowercased() }
    }

    // MARK: - Public actions
    func toggle(word: String) {
        if let idx = currentOptions.firstIndex(where: { $0.lowercased() == word.lowercased() }) {
            currentOptions.remove(at: idx)
        } else {
            currentOptions.append(word)
        }
        recomputeExtraWords()
    }

    @MainActor
    private func loadExtraWords() async {
        isLoadingWords = true
        defer { isLoadingWords = false }
        do {
            // create 화면과 동일한 로직 재사용
            let w = try await WordDataSource.shared.word(id: example.wordId)
            if let lessonId = w.lessonId {
                let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
                self.wordsLearned = try await WordDataSource.shared.wordsLessThan(unit: lesson.unit)
            }
            recomputeExtraWords()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func saveOptions() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // 서버로 전송할 wordOptions 구성
        let wordsOptions: [ExerciseWordOption] = currentOptions.map {
            let t = ExerciseOptionTranslation(langCode: .enUS, text: $0.lowercased())
            return ExerciseWordOption(translations: [t])
        }

        // translations는 기존 그대로 유지 (영문 content만 사용)
        let trans = ExerciseTranslation(langCode: .enUS, content: content, question: nil)

        let options = exercise.options.map {
            ExerciseOptionUpdate(translations: $0.translations)
        }
        
        let update = ExerciseUpdate(
            exampleId: exercise.exampleId,
            type: .select,
            wordOptions: wordsOptions,
            options: options,       // 기존 보기(선지)가 있다면 유지
            translations: [trans]
        )

        do {
            let updated = try await ExerciseDataSource.shared.update(id: exercise.id, exercise: update)
            self.exercise = updated
            self.currentOptions = Self.enOptions(from: updated)
            self.originalOptions = self.currentOptions
            self.recomputeExtraWords()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        errorMessage = nil
        do {
            try await ExerciseDataSource.shared.delete(id: exercise.id)
            isDeleting = false
            return true
        } catch {
            isDeleting = false
            errorMessage = error.localizedDescription
            return false
        }
    }
}


