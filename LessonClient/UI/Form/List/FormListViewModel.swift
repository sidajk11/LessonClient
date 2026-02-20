//
//  FormListViewModel.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import Foundation

@MainActor
final class FormListViewModel: ObservableObject {

    // MARK: - Input
    let wordId: Int?

    // MARK: - UI State
    @Published var items: [WordFormRead] = []
    @Published var selection: Set<Int> = []      // Table selection (id)
    @Published var query: String = ""
    @Published var selectedFormType: String? = nil

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Editor sheet state
    @Published var isPresentingEditor: Bool = false
    @Published var editingItem: WordFormRead? = nil

    // MARK: - Pagination
    private(set) var limit: Int = 50
    private var offset: Int = 0
    private var canLoadMore: Bool = true

    private let ds = WordFormDataSource.shared

    init(wordId: Int? = nil) {
        self.wordId = wordId
    }

    // MARK: - Load
    func refresh() async {
        offset = 0
        canLoadMore = true
        await load(reset: true)
    }

    func loadMoreIfNeeded(currentItem: WordFormRead?) async {
        guard let currentItem else { return }
        guard canLoadMore, !isLoading else { return }

        let thresholdIndex = items.index(items.endIndex, offsetBy: -10, limitedBy: items.startIndex) ?? items.startIndex
        if items.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex {
            await load(reset: false)
        }
    }

    private func load(reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let result = try await ds.listWordForms(
                wordId: wordId,
                formType: selectedFormType,
                q: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : query,
                limit: limit,
                offset: offset
            )

            if reset {
                items = result
                selection.removeAll()
            } else {
                let existing = Set(items.map { $0.id })
                items.append(contentsOf: result.filter { !existing.contains($0.id) })
            }

            canLoadMore = result.count == limit
            offset += result.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Actions
    func openCreate() {
        editingItem = nil
        isPresentingEditor = true
    }

    func openEdit(_ item: WordFormRead) {
        editingItem = item
        isPresentingEditor = true
    }

    func openEditSelected() {
        guard let id = selection.first,
              let item = items.first(where: { $0.id == id }) else { return }
        openEdit(item)
    }
    
    func onAppearRefreshIfNeeded() async {
        // 항상 새로고침해도 되고, 필요 시 플래그 써도 됨
        await refresh()
    }

    func delete(_ item: WordFormRead) async {
        errorMessage = nil
        do {
            try await ds.deleteWordForm(id: item.id)
            items.removeAll { $0.id == item.id }
            selection.remove(item.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelected() async {
        let ids = selection
        guard !ids.isEmpty else { return }
        for id in ids {
            if let item = items.first(where: { $0.id == id }) {
                await delete(item)
            }
        }
    }

    func upsert(formId: Int?, wordId: Int, form: String, formType: String?) async {
        errorMessage = nil
        do {
            if let formId {
                let updated = try await ds.updateWordForm(
                    id: formId,
                    wordId: wordId,
                    form: form,
                    formType: formType
                )
                if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                    items[idx] = updated
                } else {
                    items.insert(updated, at: 0)
                }
            } else {
                // NOTE: DS가 formType을 non-optional로 받는다면 nil 대신 ""로 넘기도록 맞춰줘야 함
                let created = try await ds.createWordForm(
                    wordId: wordId,
                    form: form,
                    formType: formType ?? ""
                )
                items.insert(created, at: 0)
            }
            isPresentingEditor = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
