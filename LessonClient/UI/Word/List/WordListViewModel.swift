//
//  VocabularyListViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

@MainActor
final class VocabularyListViewModel: ObservableObject {
    // UI State
    @Published var items: [Vocabulary] = []
    @Published var searchText: String = ""
    @Published var levelText: String = ""     // free-form, parsed to Int?
    @Published var isLoading: Bool = false
    @Published var error: String?

    // Initial load
    func load() async {
        await fetchAll()
    }

    // Search action (q + level)
    func search() async {
        let trimmed = levelText.trimmingCharacters(in: .whitespacesAndNewlines)
        let levelParam: Int? = trimmed.isEmpty ? nil : Int(trimmed)

        // Optional: validate numeric level
        if !trimmed.isEmpty && levelParam == nil {
            error = "레벨은 숫자로 입력해 주세요."
            return
        }

        do {
            isLoading = true
            defer { isLoading = false }
            items = try await VocabularyDataSource.shared.searchVocabularys(
                q: searchText,
                level: levelParam,
                limit: 50
            )
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    // Callbacks from child screens
    func didCreate(_ words: [Vocabulary]) {
        items.insert(contentsOf: words, at: 0)
    }
    func didImport(_ list: [Vocabulary]) {
        items.insert(contentsOf: list, at: 0)
    }

    // MARK: - Private
    private func fetchAll() async {
        do {
            isLoading = true
            defer { isLoading = false }
            items = try await VocabularyDataSource.shared.words()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
