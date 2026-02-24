//
//  PhraseDetailViewModel.swift
//  LessonClient
//
//  Created by ym on 2/24/26.
//

import Foundation

@MainActor
final class PhraseDetailViewModel: ObservableObject {
    let phraseId: Int

    @Published var phrase: PhraseRead?

    @Published var text: String = ""
    @Published var lessonTargetIdText: String = ""
    @Published var translationsText: String = ""

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isDeleting: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    init(phraseId: Int) {
        self.phraseId = phraseId
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let row = try await PhraseDataSource.shared.phrase(id: phraseId)
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
            let updated = try await PhraseDataSource.shared.updatePhrase(
                id: phraseId,
                text: text.trimmedNilIfEmpty,
                lessonTargetId: parseOptionalInt(lessonTargetIdText),
                translations: parseTranslations(from: translationsText)
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
            try await PhraseDataSource.shared.deletePhrase(id: phraseId)
            infoMessage = "삭제되었습니다."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(row: PhraseRead) {
        phrase = row
        text = row.text
        lessonTargetIdText = row.lessonTargetId.map(String.init) ?? ""
        translationsText = row.translations
            .map { "\($0.lang): \($0.text)" }
            .joined(separator: "\n")
    }

    private func parseOptionalInt(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return Int(trimmed)
    }

    private func parseTranslations(from raw: String) -> [PhraseTranslationSchema]? {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.isEmpty { return nil }

        let parsed = lines.compactMap { line -> PhraseTranslationSchema? in
            guard let idx = line.firstIndex(of: ":") else { return nil }
            let lang = String(line[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            let text = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lang.isEmpty, !text.isEmpty else { return nil }
            return PhraseTranslationSchema(lang: lang, text: text)
        }

        return parsed.isEmpty ? nil : parsed
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
