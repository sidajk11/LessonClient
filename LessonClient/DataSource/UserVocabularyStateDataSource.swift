//
//  UserLessonTargetStateDataSource.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import Foundation

final class UserVocabularyStateDataSource {
    static let shared = UserVocabularyStateDataSource()
    private let api = APIClient.shared
    private init() {}

    func listUserVocabularyStates(
        userId: Int? = nil,
        vocabularyId: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [UserVocabularyStateRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 500))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        if let userId { query.append(.init(name: "user_id", value: String(userId))) }
        if let vocabularyId { query.append(.init(name: "vocabulary_id", value: String(vocabularyId))) }

        return try await api.request(
            "GET",
            "admin/user-vocabulary-states",
            query: query,
            as: [UserVocabularyStateRead].self
        )
    }

    @discardableResult
    func createUserVocabularyState(payload: UserVocabularyStateCreate) async throws -> UserVocabularyStateRead {
        return try await api.request(
            "POST",
            "admin/user-vocabulary-states",
            jsonBody: payload.toDict(),
            as: UserVocabularyStateRead.self
        )
    }

    func userVocabularyState(id stateId: Int) async throws -> UserVocabularyStateRead {
        try await api.request(
            "GET",
            "admin/user-vocabulary-states/\(stateId)",
            as: UserVocabularyStateRead.self
        )
    }

    @discardableResult
    func updateUserVocabularyState(
        id stateId: Int,
        payload: UserVocabularyStateUpdate
    ) async throws -> UserVocabularyStateRead {
        return try await api.request(
            "PUT",
            "admin/user-vocabulary-states/\(stateId)",
            jsonBody: payload.toDict(),
            as: UserVocabularyStateRead.self
        )
    }

    func deleteUserVocabularyState(id stateId: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/user-vocabulary-states/\(stateId)",
            as: Empty.self
        )
    }
}

typealias UserLessonTargetStateDataSource = UserVocabularyStateDataSource
