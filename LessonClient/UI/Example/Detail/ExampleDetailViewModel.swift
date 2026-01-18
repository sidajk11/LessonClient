// ExampleDetailViewModel.swift

import Foundation

@MainActor
final class ExampleDetailViewModel: ObservableObject {
    let exampleId: Int
    let lesson: Lesson?
    let word: Vocabulary?

    @Published var example: Example?
    @Published var sentence: String = ""           // en
    @Published var translationText: String = ""   // excluding en
    @Published var isSaving = false
    @Published var error: String?
    @Published var info: String?

    init(exampleId: Int, lesson: Lesson?, word: Vocabulary?) {
        self.exampleId = exampleId
        self.lesson = lesson
        self.word = word
    }

    func load() async {
        do {
            let ex = try await ExampleDataSource.shared.example(id: exampleId)
            example = ex
            sentence = ex.text
            let lines = ex.translations
                .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
                .map { "\($0.langCode): \($0.text)" }
                .joined(separator: "\n")
            translationText = lines
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func save() async {
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "문장을 입력해 주세요."
            return
        }
        do {
            isSaving = true
            defer { isSaving = false }

            let payload = [ExampleTranslation].parse(from: translationText)

            let updated = try await ExampleDataSource.shared.updateExample(
                id: exampleId,
                text: sentence.trimmed,
                translations: payload
            )
            example = updated
            info = "저장되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
