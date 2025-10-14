// ExampleDetailViewModel.swift

import Foundation

@MainActor
final class ExampleDetailViewModel: ObservableObject {
    let exampleId: Int

    @Published var example: Example?
    @Published var sentence: String = ""           // en
    @Published var translationsText: String = ""   // excluding en
    @Published var isSaving = false
    @Published var error: String?
    @Published var info: String?

    init(exampleId: Int) { self.exampleId = exampleId }

    func load() async {
        do {
            let ex = try await ExampleDataSource.shared.example(id: exampleId)
            example = ex
            sentence = ex.text
            let lines = ex.translations
                .filter { $0.langCode.lowercased() != "en" }
                .sorted { $0.langCode < $1.langCode }
                .map { "\($0.langCode): \($0.text)" }
                .joined(separator: "\n")
            translationsText = lines
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

            var payload: [ExampleTranslation] = [ExampleTranslation(langCode: "en", text: sentence.trimmingCharacters(in: .whitespacesAndNewlines))]
            let extras = [ExampleTranslation].parse(from: translationsText).filter { $0.langCode.lowercased() != "en" }
            payload.append(contentsOf: extras)

            let updated = try await ExampleDataSource.shared.replaceTranslations(
                exampleId: exampleId,
                translations: payload
            )
            example = updated
            info = "저장되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
