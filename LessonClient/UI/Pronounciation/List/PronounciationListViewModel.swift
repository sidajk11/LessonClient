//
//  PronounciationListViewModel.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation

@MainActor
final class PronounciationListViewModel: ObservableObject {
    enum DialectFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case us = "US"
        case uk = "UK"
        case au = "AU"

        var id: String { rawValue }

        var dialect: Dialect? {
            switch self {
            case .all: nil
            case .us: .us
            case .uk: .uk
            case .au: .au
            }
        }
    }

    @Published var pronunciations: [PronunciationRead] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var wordIdText: String = ""
    @Published var senseIdText: String = ""
    @Published var dialectFilter: DialectFilter = .all

    private let ds = PronunciationDataSource.shared
    private let limit: Int = 50
    private var offset: Int = 0
    private var hasMore: Bool = true

    func refresh() async {
        errorMessage = nil

        guard let wordId = parsedIdAllowingEmpty(from: wordIdText, label: "wordId"),
              let senseId = parsedIdAllowingEmpty(from: senseIdText, label: "senseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        offset = 0
        hasMore = true

        do {
            let result = try await ds.listPronunciations(
                wordId: wordId,
                senseId: senseId,
                dialect: dialectFilter.dialect,
                limit: limit,
                offset: offset
            )
            pronunciations = result
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current item: PronunciationRead) async {
        guard !isLoading, hasMore else { return }
        guard item.id == pronunciations.last?.id else { return }

        guard let wordId = parsedIdAllowingEmpty(from: wordIdText, label: "wordId"),
              let senseId = parsedIdAllowingEmpty(from: senseIdText, label: "senseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ds.listPronunciations(
                wordId: wordId,
                senseId: senseId,
                dialect: dialectFilter.dialect,
                limit: limit,
                offset: offset
            )
            pronunciations.append(contentsOf: result)
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: PronunciationRead) async {
        errorMessage = nil
        do {
            try await ds.deletePronunciation(id: item.id)
            pronunciations.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Returns:
    // - .some(nil): empty input (means "no filter")
    // - .some(Int): valid numeric filter
    // - .none: invalid input
    private func parsedIdAllowingEmpty(from raw: String, label: String) -> Int?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }
        guard let value = Int(trimmed) else {
            errorMessage = "\(label)는 숫자여야 합니다."
            return .none
        }
        return .some(value)
    }
}
