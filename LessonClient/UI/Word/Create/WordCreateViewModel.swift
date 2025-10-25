//
//  WordCreateViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation
import Combine

@MainActor
final class WordCreateViewModel: ObservableObject {
    // Input
    @Published var text: String = ""
    /**
     예)
     my
     ko: 나의 / 내
     es: mi
     */
    @Published var translationText: String = ""
    @Published var lessonId: Int? = nil

    // State
    @Published var isSaving = false
    @Published var error: String?

    // Output
    var canSubmit: Bool {
        let wordOK = !text.trimmed.isEmpty
        let translations = [WordTranslation].parse(from: translationText)
        let hasAnyValid = translations.isEmpty == false
        return wordOK && hasAnyValid && !isSaving
    }

    // Action
    func createWord() async throws -> Word {
        guard canSubmit else { throw NSError(domain: "invalid.form", code: 0, userInfo: [NSLocalizedDescriptionKey: "입력을 확인해 주세요."]) }
        isSaving = true
        defer { isSaving = false }

        let translations = [WordTranslation].parse(from: translationText)

        return try await WordDataSource.shared.createWord(
            text: text.trimmed,
            lessonId: lessonId,
            translations: translations
        )
    }
}


