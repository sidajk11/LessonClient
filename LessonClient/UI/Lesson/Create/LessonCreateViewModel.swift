//
//  LessonCreateViewModel.swift
//  LessonClient
//
//  Created by 정영민 on 8/31/25.
//  MVVM refactor on 10/13/25
//

import Foundation

@MainActor
final class LessonCreateViewModel: ObservableObject {
    // Inputs
    @Published var unitText: String = "1"
    @Published var levelText: String = "1"
    @Published var topic: String = ""
    @Published var grammar: String = ""

    // UI State
    @Published var isSaving: Bool = false
    @Published var error: String?

    // Derived
    var canSave: Bool {
        guard let unit = Int(unitText), let level = Int(levelText) else { return false }
        
        return unit >= 1 && level >= 1 && !isSaving
    }

    /// Create lesson on server and return it
    func createLesson() async throws -> Lesson {
        guard let unit = Int(unitText), let level = Int(levelText) else {
            throw NSError(domain: "form.invalid", code: -1, userInfo: [NSLocalizedDescriptionKey: "입력을 확인해 주세요."])
        }
        isSaving = true
        defer { isSaving = false }

        let lt = LessonTranslation(langCode: .ko, topic: topic)
        let lesson = try await LessonDataSource.shared.createLesson(
            unit: unit,
            level: level,
            grammar: grammar.isEmpty ? nil : grammar,
            translations: [lt]
        )
        return lesson
    }
}
