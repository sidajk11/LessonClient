//
//  PhraseListViewModel.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import Foundation

@MainActor
final class PhraseListViewModel: ObservableObject {
    @Published var items: [PhraseRead] = []
    @Published var q: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await PhraseDataSource.shared.listPhrases(
                q: q.trimmedNilIfEmpty,
                limit: 50,
                offset: 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

