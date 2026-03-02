//
//  UserLessonTargetStateListViewModel.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

@MainActor
final class UserLessonTargetStateListViewModel: ObservableObject {
    @Published var items: [UserLessonTargetStateRead] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var userIdText: String = ""
    @Published var lessonTargetIdText: String = ""

    private let ds = UserLessonTargetStateDataSource.shared
    private let limit: Int = 100
    private var offset: Int = 0
    private var hasMore: Bool = true

    func refresh() async {
        errorMessage = nil

        guard let userId = parsedIdAllowingEmpty(from: userIdText, label: "userId"),
              let lessonTargetId = parsedIdAllowingEmpty(from: lessonTargetIdText, label: "lessonTargetId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        offset = 0
        hasMore = true

        do {
            let result = try await ds.listUserLessonTargetStates(
                userId: userId,
                lessonTargetId: lessonTargetId,
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

    func loadMoreIfNeeded(current item: UserLessonTargetStateRead) async {
        guard !isLoading, hasMore else { return }
        guard item.id == items.last?.id else { return }

        guard let userId = parsedIdAllowingEmpty(from: userIdText, label: "userId"),
              let lessonTargetId = parsedIdAllowingEmpty(from: lessonTargetIdText, label: "lessonTargetId") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ds.listUserLessonTargetStates(
                userId: userId,
                lessonTargetId: lessonTargetId,
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

    func delete(_ item: UserLessonTargetStateRead) async {
        errorMessage = nil
        do {
            try await ds.deleteUserLessonTargetState(id: item.id)
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
