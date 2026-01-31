//
//  PracticeDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import SwiftUI
import Combine

final class PracticeDetailViewModel: ObservableObject {
    @Published var example: Example
    @Published var practice: Exercise

    @Published var sentence: String = ""
    @Published var content: String = ""
    @Published var optionsText: String = ""

    // ✅ 더미 단어 관리 상태
    @Published var currentOptions: [String] = []  // 현재 보기(enUS)
    @Published var extraVocabularys: [String] = []      // 추가 가능 단어
    @Published var isLoadingVocabularys: Bool = false
    @Published var isSaving: Bool = false
    @Published var hasChanges: Bool = false

    @Published var isDeleting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showDeleteConfirm: Bool = false

    private var originalOptions: [String] = []
    private var wordsLearned: [Vocabulary] = []

    init(example: Example, practice: Exercise) {
        self.example = example
        self.practice = practice

        if practice.type == .combine {
            sentence = example.translations.text(langCode: .ko)
            content = practice.prompt ?? ""
            optionsText = practice.options.map { $0.text }.joined(separator: ", ")
        } else if practice.type == .select {
            sentence = example.translations.text(langCode: .ko)
            content = practice.prompt ?? ""
            optionsText = practice.options.map { $0.text }.joined(separator: ", ")
        }

        // ✅ select 타입일 때 편집 데이터 준비
        if practice.type == .select {
            let opts = Self.enOptions(from: practice)
            self.currentOptions = opts
            self.originalOptions = opts
            Task { await loadExtraVocabularys() }
        }
    }

    // MARK: - Helpers
    private static func enOptions(from practice: Exercise) -> [String] {
        practice.options.compactMap {
            $0.text
        }
    }

    private func recomputeExtraVocabularys() {
        // learned - currentOptions (대소문자 무시)
        let learned = Set(wordsLearned.map { NL.lowercaseAvailable(sentence: "", word: $0.text) ? $0.text.lowercased() : $0.text })
        let current = Set(currentOptions.map { NL.lowercaseAvailable(sentence: "", word: $0) ? $0.lowercased() : $0 })
        let extra = Array(learned).subtractingWords(Array(current))
        // 보기 좋게 알파벳 정렬 (원하면 제거)
        self.extraVocabularys = extra.sorted()
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
        recomputeExtraVocabularys()
    }

    @MainActor
    private func loadExtraVocabularys() async {
        isLoadingVocabularys = true
        defer { isLoadingVocabularys = false }
        do {
            // create 화면과 동일한 로직 재사용
            let w = try await VocabularyDataSource.shared.word(id: example.wordId)
            if let lessonId = w.lessonId {
                let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
                self.wordsLearned = try await VocabularyDataSource.shared.wordsLessThan(unit: lesson.unit)
            }
            recomputeExtraVocabularys()
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
        let options: [ExerciseOptionUpdate] = currentOptions.map {
            return ExerciseOptionUpdate(text: $0.lowercased())
        }

        // translations는 기존 그대로 유지 (영문 content만 사용)
        let trans = ExerciseTranslation(langCode: .enUS, question: nil)
        
        let update = ExerciseUpdate(
            exampleId: practice.exampleId,
            type: .select,
            prompt: content,
            options: options,       // 기존 보기(선지)가 있다면 유지
            translations: [trans]
        )

        do {
            let updated = try await PracticeDataSource.shared.update(id: practice.id, practice: update)
            self.practice = updated
            self.currentOptions = Self.enOptions(from: updated)
            self.originalOptions = self.currentOptions
            self.recomputeExtraVocabularys()
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
            try await PracticeDataSource.shared.delete(id: practice.id)
            isDeleting = false
            return true
        } catch {
            isDeleting = false
            errorMessage = error.localizedDescription
            return false
        }
    }
}


