//
//  WordDetailViewModel.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import Foundation

@MainActor
final class WordDetailViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var word: WordRead?
    @Published private(set) var senses: [WordSenseRead] = []

    let wordId: Int
    private let dataSource: WordDataSource

    // 전체 삭제용
    @Published var showDeleteAllConfirm: Bool = false
    @Published var isDeletingAll: Bool = false

    init(wordId: Int, dataSource: WordDataSource = .shared) {
        self.wordId = wordId
        self.dataSource = dataSource
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let word = try await dataSource.word(id: wordId)
            self.word = word
            self.senses = word.senses
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteAllSenses() async {
        guard !isDeletingAll else { return }
        guard !senses.isEmpty else { return }

        isDeletingAll = true
        errorMessage = nil
        defer { isDeletingAll = false }

        // 현재 목록 스냅샷
        let toDelete = senses

        do {
            // 순차 삭제(서버 부하/레이트리밋 안전)
            for sense in toDelete {
                try await dataSource.deleteWordSense(senseId: sense.id)
                // 성공한 건 UI에서 바로 제거
                senses.removeAll { $0.id == sense.id }
            }
        } catch {
            // 중간 실패 시: 남아있는 senses는 그대로 유지(이미 지운 건 반영됨)
            errorMessage = error.localizedDescription
        }
    }
}
