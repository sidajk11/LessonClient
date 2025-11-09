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
    /**
     예)
     my
     ko: 나의 / 내
     es: mi
     */
    @Published var text: String = ""
    @Published var lessonId: Int? = nil

    // State
    @Published var isSaving = false
    @Published var error: String?

    // Output
    var canSubmit: Bool {
        return !text.isEmpty
    }

    // Action
    func createWord() async throws -> [Word] {
        guard canSubmit else { throw NSError(domain: "invalid.form", code: 0, userInfo: [NSLocalizedDescriptionKey: "입력을 확인해 주세요."]) }
        isSaving = true
        defer { isSaving = false }
        
        text = text.replacingOccurrences(of: "’", with: "'")
        
        var words: [Word] = []
        let paras = text.components(separatedBy: "\n\n")
        for para in paras {
            var components = para.components(separatedBy: .newlines)
            let text = components.removeFirst().trimmed
            let translations = [WordTranslation].parse(from: components)

            let word = try await WordDataSource.shared.createWord(
                text: text.trimmed,
                lessonId: lessonId,
                translations: translations
            )
            words.append(word)
        }

        return words
    }
}


