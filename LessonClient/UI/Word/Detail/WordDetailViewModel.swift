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
            // senses listing method assumed: listWordSenses(wordId:)
            let senses: [WordSenseRead] = word.senses
            
            self.word = word
            self.senses = senses
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
