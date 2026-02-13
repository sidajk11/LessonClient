//
//  WordListViewModel.swift
//  LessonClient
//
//  Created by ym on 2/12/26.
//

import Foundation

@MainActor
final class WordListViewModel: ObservableObject {
    @Published var words: [WordRead] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Filters
    @Published var q: String = ""
    @Published var kind: String = ""   // 필요 없으면 제거 가능
    @Published var pos: String = ""    // 필요 없으면 제거 가능

    // Paging
    private(set) var limit: Int = 50
    private var offset: Int = 0
    private var hasMore: Bool = true

    private let ds = WordDataSource.shared

    func refresh() async {
        isLoading = true
        errorMessage = nil
        offset = 0
        hasMore = true

        do {
            let result = try await ds.listWords(
                q: q.isEmpty ? nil : q,
                kind: kind.isEmpty ? nil : kind,
                limit: limit,
                offset: offset
            )
            words = result
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(current item: WordRead) async {
        guard !isLoading, hasMore else { return }
        guard item.id == words.last?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ds.listWords(
                q: q.isEmpty ? nil : q,
                kind: kind.isEmpty ? nil : kind,
                limit: limit,
                offset: offset
            )
            words.append(contentsOf: result)
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
