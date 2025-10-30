// ExampleCreateViewModel.swift

import Foundation

@MainActor
final class ExampleCreateViewModel: ObservableObject {
    let wordId: Int
    @Published var text: String = ""
    @Published var isSaving = false
    @Published var error: String?

    init(wordId: Int) { self.wordId = wordId }

    func create() async throws -> Example {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "invalid.form", code: 0, userInfo: [NSLocalizedDescriptionKey: "문장을 입력해 주세요."])
        }
        isSaving = true
        defer { isSaving = false }

        var components = text.components(separatedBy: .newlines)
        let text = components.removeFirst().trimmed
        let translations = [ExampleTranslation].parse(from: components)

        return try await ExampleDataSource.shared.createExample(
            text: text,
            wordId: wordId,
            translations: translations
        )
    }
}
