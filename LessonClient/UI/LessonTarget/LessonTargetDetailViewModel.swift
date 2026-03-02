//
//  LessonTargetDetailViewModel.swift
//  LessonClient
//
//  Created by ym on 2/24/26.
//

import Foundation

@MainActor
final class LessonTargetDetailViewModel: ObservableObject {
    let targetId: Int

    @Published var item: LessonTargetRead?

    @Published var lessonIdText: String = ""
    @Published var targetType: String = ""
    @Published var vocabularyIdText: String = ""
    @Published var displayText: String = ""
    @Published var sortIndexText: String = "0"

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isDeleting: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    init(targetId: Int) {
        self.targetId = targetId
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let row = try await LessonTargetDataSource.shared.lessonTarget(id: targetId)
            apply(row: row)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        do {
            let updated = try await LessonTargetDataSource.shared.updateLessonTarget(
                id: targetId,
                lessonId: parseOptionalInt(lessonIdText),
                targetType: targetType.trimmedNilIfEmpty,
                vocabularyId: parseOptionalInt(vocabularyIdText),
                displayText: displayText.trimmedNilIfEmpty,
                sortIndex: parseOptionalInt(sortIndexText)
            )
            apply(row: updated)
            infoMessage = "저장되었습니다."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await LessonTargetDataSource.shared.deleteLessonTarget(id: targetId)
            infoMessage = "삭제되었습니다."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(row: LessonTargetRead) {
        item = row
        lessonIdText = String(row.lessonId)
        targetType = row.targetType
        vocabularyIdText = row.vocabularyId.map(String.init) ?? ""
        displayText = row.displayText
        sortIndexText = String(row.sortIndex)
    }

    private func parseOptionalInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return Int(trimmed)
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
