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
    @Published var deletingWordId: Int?
    @Published var errorMessage: String?

    // Filters
    @Published var q: String = ""
    @Published var wordIdText: String = ""
    @Published var kind: String = ""   // 필요 없으면 제거 가능
    @Published var pos: String = ""    // 필요 없으면 제거 가능

    // Paging
    private(set) var limit: Int = 50
    private var offset: Int = 0
    private var hasMore: Bool = true

    private let ds = WordDataSource.shared

    private var exactWordId: Int? {
        let trimmed = wordIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        offset = 0
        hasMore = true

        if let wordId = exactWordId {
            guard wordId > 0 else {
                errorMessage = "word_id는 1 이상의 숫자여야 합니다."
                words = []
                isLoading = false
                return
            }

            do {
                // word_id 검색은 정확히 1건만 조회합니다.
                let word = try await ds.word(id: wordId)
                words = [word]
                hasMore = false
            } catch {
                words = []
                errorMessage = error.localizedDescription
            }

            isLoading = false
            return
        }

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
        guard exactWordId == nil else { return }
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

    func deleteWord(_ word: WordRead) async {
        guard deletingWordId == nil else { return }

        deletingWordId = word.id
        errorMessage = nil
        defer { deletingWordId = nil }

        do {
            for sense in word.senses {
                try await ds.deleteWordSense(senseId: sense.id)
            }

            try await ds.deleteWord(id: word.id)
            words.removeAll { $0.id == word.id }
            offset = max(0, offset - 1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
