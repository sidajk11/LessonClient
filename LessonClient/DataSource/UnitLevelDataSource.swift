//
//  UnitLevelDataSource.swift
//  LessonClient
//
//  Created by Codex on 4/23/26.
//

import Foundation

final class UnitLevelDataSource {
    static let shared = UnitLevelDataSource()
    private let api = APIClient.shared

    private init() {}

    func listUnitLevels(
        level: Int? = nil,
        startUnit: Int? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [UnitLevelRead] {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: String(min(max(limit, 1), 200))),
            .init(name: "offset", value: String(max(offset, 0)))
        ]

        if let level { query.append(.init(name: "level", value: String(level))) }
        if let startUnit { query.append(.init(name: "start_unit", value: String(startUnit))) }

        return try await api.request(
            "GET",
            "admin/unit-levels",
            query: query,
            as: [UnitLevelRead].self
        )
    }

    @discardableResult
    func createUnitLevel(payload: UnitLevelCreate) async throws -> UnitLevelRead {
        try await api.request(
            "POST",
            "admin/unit-levels",
            jsonBody: payload.toDict(),
            as: UnitLevelRead.self
        )
    }

    func unitLevel(id unitLevelId: Int) async throws -> UnitLevelRead {
        try await api.request(
            "GET",
            "admin/unit-levels/\(unitLevelId)",
            as: UnitLevelRead.self
        )
    }

    @discardableResult
    func updateUnitLevel(
        id unitLevelId: Int,
        payload: UnitLevelUpdate
    ) async throws -> UnitLevelRead {
        try await api.request(
            "PUT",
            "admin/unit-levels/\(unitLevelId)",
            jsonBody: payload.toDict(),
            as: UnitLevelRead.self
        )
    }

    func deleteUnitLevel(id unitLevelId: Int) async throws {
        _ = try await api.request(
            "DELETE",
            "admin/unit-levels/\(unitLevelId)",
            as: Empty.self
        )
    }
}
