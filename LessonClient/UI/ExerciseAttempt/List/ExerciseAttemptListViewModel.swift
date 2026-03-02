//
//  ExerciseAttemptListViewModel.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

@MainActor
final class ExerciseAttemptListViewModel: ObservableObject {
    enum CorrectnessFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case correct = "Correct"
        case incorrect = "Incorrect"

        var id: String { rawValue }

        var value: Bool? {
            switch self {
            case .all: nil
            case .correct: true
            case .incorrect: false
            }
        }
    }

    @Published var attempts: [ExerciseAttemptRead] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var userIdText: String = ""
    @Published var exerciseIdText: String = ""
    @Published var correctnessFilter: CorrectnessFilter = .all

    private let ds = ExerciseAttemptDataSource.shared
    private let limit: Int = 100
    private var offset: Int = 0
    private var hasMore: Bool = true

    func refresh() async {
        errorMessage = nil

        guard let userId = parsedIdAllowingEmpty(from: userIdText, label: "userId"),
              let exerciseId = parsedIdAllowingEmpty(from: exerciseIdText, label: "exerciseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        offset = 0
        hasMore = true

        do {
            let result = try await ds.listExerciseAttempts(
                userId: userId,
                exerciseId: exerciseId,
                isCorrect: correctnessFilter.value,
                limit: limit,
                offset: offset
            )
            attempts = result
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current item: ExerciseAttemptRead) async {
        guard !isLoading, hasMore else { return }
        guard item.id == attempts.last?.id else { return }

        guard let userId = parsedIdAllowingEmpty(from: userIdText, label: "userId"),
              let exerciseId = parsedIdAllowingEmpty(from: exerciseIdText, label: "exerciseId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ds.listExerciseAttempts(
                userId: userId,
                exerciseId: exerciseId,
                isCorrect: correctnessFilter.value,
                limit: limit,
                offset: offset
            )
            attempts.append(contentsOf: result)
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: ExerciseAttemptRead) async {
        errorMessage = nil
        do {
            try await ds.deleteExerciseAttempt(id: item.id)
            attempts.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func formattedCreatedAt(_ date: Date?) -> String {
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
