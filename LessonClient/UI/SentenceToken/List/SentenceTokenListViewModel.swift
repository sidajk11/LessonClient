//
//  SentenceTokenListViewModel.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation

@MainActor
final class SentenceTokenListViewModel: ObservableObject {
    @Published var tokens: [SentenceTokenRead] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var exampleIdText: String = ""
    @Published var phraseIdText: String = ""
    @Published var wordIdText: String = ""
    @Published var formIdText: String = ""
    @Published var senseIdText: String = ""

    private let ds = SentenceTokenDataSource.shared
    private let limit: Int = 100
    private var offset: Int = 0
    private var hasMore: Bool = true

    func refresh() async {
        errorMessage = nil

        guard let exampleId = parsedIdAllowingEmpty(from: exampleIdText, label: "exampleId"),
              let phraseId = parsedIdAllowingEmpty(from: phraseIdText, label: "phraseId"),
              let wordId = parsedIdAllowingEmpty(from: wordIdText, label: "wordId"),
              let formId = parsedIdAllowingEmpty(from: formIdText, label: "formId"),
              let senseId = parsedIdAllowingEmpty(from: senseIdText, label: "senseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        offset = 0
        hasMore = true

        do {
            let result = try await ds.listSentenceTokens(
                exampleId: exampleId,
                phraseId: phraseId,
                wordId: wordId,
                formId: formId,
                senseId: senseId,
                limit: limit,
                offset: offset
            )
            tokens = result
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current item: SentenceTokenRead) async {
        guard !isLoading, hasMore else { return }
        guard item.id == tokens.last?.id else { return }

        guard let exampleId = parsedIdAllowingEmpty(from: exampleIdText, label: "exampleId"),
              let phraseId = parsedIdAllowingEmpty(from: phraseIdText, label: "phraseId"),
              let wordId = parsedIdAllowingEmpty(from: wordIdText, label: "wordId"),
              let formId = parsedIdAllowingEmpty(from: formIdText, label: "formId"),
              let senseId = parsedIdAllowingEmpty(from: senseIdText, label: "senseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ds.listSentenceTokens(
                exampleId: exampleId,
                phraseId: phraseId,
                wordId: wordId,
                formId: formId,
                senseId: senseId,
                limit: limit,
                offset: offset
            )
            tokens.append(contentsOf: result)
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: SentenceTokenRead) async {
        errorMessage = nil
        do {
            try await ds.deleteSentenceToken(id: item.id)
            tokens.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parsedIdAllowingEmpty(from raw: String, label: String) -> Int?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }
        guard let value = Int(trimmed), value >= 1 else {
            errorMessage = "\(label)는 1 이상의 숫자여야 합니다."
            return .none
        }
        return .some(value)
    }
}
