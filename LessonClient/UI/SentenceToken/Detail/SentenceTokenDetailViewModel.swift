//
//  SentenceTokenDetailViewModel.swift
//  LessonClient
//
//  Created by Codex on 3/4/26.
//

import Foundation

@MainActor
final class SentenceTokenDetailViewModel: ObservableObject {
    let tokenId: Int

    @Published var token: SentenceTokenRead?

    @Published var exampleIdText: String = ""
    @Published var tokenIndexText: String = ""
    @Published var surfaceText: String = ""
    @Published var phraseIdText: String = ""
    @Published var wordIdText: String = ""
    @Published var formIdText: String = ""
    @Published var senseIdText: String = ""
    @Published var posText: String = ""
    @Published var startIndexText: String = ""
    @Published var endIndexText: String = ""

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let ds = SentenceTokenDataSource.shared

    init(tokenId: Int) {
        self.tokenId = tokenId
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await ds.sentenceToken(id: tokenId)
            token = loaded
            bindEditorFields(from: loaded)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard !isSaving else { return }
        guard token != nil else {
            errorMessage = "저장할 token 정보가 없습니다."
            return
        }

        errorMessage = nil
        infoMessage = nil

        guard let exampleId = parseRequiredInt(exampleIdText, label: "exampleId", min: 1),
              let tokenIndex = parseRequiredInt(tokenIndexText, label: "tokenIndex", min: 0) else {
            return
        }

        let surface = surfaceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !surface.isEmpty else {
            errorMessage = "surface는 비워둘 수 없습니다."
            return
        }

        guard let phraseId = parseOptionalInt(phraseIdText, label: "phraseId", min: 1),
              let wordId = parseOptionalInt(wordIdText, label: "wordId", min: 1),
              let formId = parseOptionalInt(formIdText, label: "formId", min: 1),
              let senseId = parseOptionalInt(senseIdText, label: "senseId", min: 1),
              let startIndex = parseOptionalInt(startIndexText, label: "startIndex", min: 0),
              let endIndex = parseOptionalInt(endIndexText, label: "endIndex", min: 0) else {
            return
        }

        let pos = posText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : posText.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await ds.replaceSentenceToken(
                id: tokenId,
                exampleId: exampleId,
                tokenIndex: tokenIndex,
                surface: surface,
                phraseId: phraseId,
                wordId: wordId,
                formId: formId,
                senseId: senseId,
                pos: pos,
                startIndex: startIndex,
                endIndex: endIndex
            )
            token = updated
            bindEditorFields(from: updated)
            infoMessage = "저장되었습니다."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bindEditorFields(from token: SentenceTokenRead) {
        exampleIdText = String(token.exampleId)
        tokenIndexText = String(token.tokenIndex)
        surfaceText = token.surface
        phraseIdText = token.phraseId.map(String.init) ?? ""
        wordIdText = token.wordId.map(String.init) ?? ""
        formIdText = token.formId.map(String.init) ?? ""
        senseIdText = token.senseId.map(String.init) ?? ""
        posText = token.pos ?? ""
        startIndexText = token.startIndex.map(String.init) ?? ""
        endIndexText = token.endIndex.map(String.init) ?? ""
    }

    private func parseRequiredInt(_ raw: String, label: String, min: Int) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= min else {
            errorMessage = "\(label)는 \(min) 이상의 숫자여야 합니다."
            return nil
        }
        return value
    }

    private func parseOptionalInt(_ raw: String, label: String, min: Int) -> Int?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }
        guard let value = Int(trimmed), value >= min else {
            errorMessage = "\(label)는 비워두거나 \(min) 이상의 숫자여야 합니다."
            return .none
        }
        return .some(value)
    }
}
