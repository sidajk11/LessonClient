// ExampleCreateViewModel.swift

import Foundation

@MainActor
final class ExampleCreateViewModel: ObservableObject {
    let wordId: Int
    @Published var sentence: String = ""
    @Published var translationText: String = "" // "ko: ...\nes: ..."
    @Published var isSaving = false
    @Published var error: String?

    init(wordId: Int) { self.wordId = wordId }

    func create() async throws -> Example {
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "invalid.form", code: 0, userInfo: [NSLocalizedDescriptionKey: "문장을 입력해 주세요."])
        }
        isSaving = true
        defer { isSaving = false }

        let payload = [LocalizedText].parse(from: translationText)

        return try await ExampleDataSource.shared.createExample(
            wordId: wordId,
            text: sentence.trimmed,
            translation: payload
        )
    }
}
