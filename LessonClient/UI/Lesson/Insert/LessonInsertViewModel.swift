import Foundation

@MainActor
final class LessonInsertViewModel: ObservableObject {
    @Published var unitText = ""
    @Published var trackCode = "en-US"
    @Published var topic = ""
    @Published var grammar = ""

    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    var canInsert: Bool {
        guard let unit = Int(unitText), unit >= 1 else { return false }
        return !trackCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    func insertLesson() async throws -> Lesson {
        guard let unit = Int(unitText), unit >= 1 else {
            throw validationError("unit은 1 이상의 숫자로 입력해 주세요.")
        }

        let trimmedTrackCode = trackCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrackCode.isEmpty else {
            throw validationError("트랙 코드를 입력해 주세요.")
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGrammar = grammar.trimmingCharacters(in: .whitespacesAndNewlines)
        let translations = trimmedTopic.isEmpty
            ? nil
            : [LessonTranslation(langCode: .ko, topic: trimmedTopic)]

        return try await LessonDataSource.shared.insertLesson(
            unit: unit,
            trackCode: trimmedTrackCode,
            grammar: trimmedGrammar.isEmpty ? nil : trimmedGrammar,
            translations: translations
        )
    }

    private func validationError(_ message: String) -> NSError {
        NSError(
            domain: "lesson.insert.validation",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
