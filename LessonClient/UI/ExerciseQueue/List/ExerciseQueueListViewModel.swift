//
//  ExerciseQueueListViewModel.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

@MainActor
final class ExerciseQueueListViewModel: ObservableObject {
    enum ConsumedFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case consumed = "Consumed"
        case pending = "Pending"

        var id: String { rawValue }

        var value: Bool? {
            switch self {
            case .all: nil
            case .consumed: true
            case .pending: false
            }
        }
    }

    @Published var items: [ExerciseQueueRead] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var userIdText: String = ""
    @Published var batchIdText: String = ""
    @Published var exerciseIdText: String = ""
    @Published var consumedFilter: ConsumedFilter = .all

    private let ds = ExerciseQueueDataSource.shared
    private let limit: Int = 100
    private var offset: Int = 0
    private var hasMore: Bool = true

    func refresh() async {
        errorMessage = nil

        guard let userId = parsedIdAllowingEmpty(from: userIdText, label: "userId"),
              let batchId = parsedIdAllowingEmpty(from: batchIdText, label: "batchId"),
              let exerciseId = parsedIdAllowingEmpty(from: exerciseIdText, label: "exerciseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        offset = 0
        hasMore = true

        do {
            let result = try await ds.listExerciseQueues(
                userId: userId,
                batchId: batchId,
                exerciseId: exerciseId,
                consumed: consumedFilter.value,
                limit: limit,
                offset: offset
            )
            items = result
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current item: ExerciseQueueRead) async {
        guard !isLoading, hasMore else { return }
        guard item.id == items.last?.id else { return }

        guard let userId = parsedIdAllowingEmpty(from: userIdText, label: "userId"),
              let batchId = parsedIdAllowingEmpty(from: batchIdText, label: "batchId"),
              let exerciseId = parsedIdAllowingEmpty(from: exerciseIdText, label: "exerciseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ds.listExerciseQueues(
                userId: userId,
                batchId: batchId,
                exerciseId: exerciseId,
                consumed: consumedFilter.value,
                limit: limit,
                offset: offset
            )
            items.append(contentsOf: result)
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: ExerciseQueueRead) async {
        errorMessage = nil
        do {
            try await ds.deleteExerciseQueue(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func formattedDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return date.formatted(date: .abbreviated, time: .standard)
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
