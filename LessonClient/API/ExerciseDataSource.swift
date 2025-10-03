//
//  ExerciseDataSource.swift
//  LessonClient
//
//  Created by ymj on 10/01/25
//

import Foundation

final class ExerciseDataSource {
    static let shared = ExerciseDataSource()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Request DTOs (server payloads)

    // POST /exercises
    private struct ExerciseCreateRequest: Codable {
        let exampleId: Int
        let type: String
        let answer: String
        let options: [ExerciseOptionIn]?
        let translations: [ExerciseTranslationIn]?

        enum CodingKeys: String, CodingKey {
            case exampleId = "example_id"
            case type
            case answer
            case options
            case translations
        }
    }

    // PUT /exercises/{id}
    private struct ExerciseUpdateRequest: Codable {
        let exampleId: Int?
        let type: String?
        let answer: String?
        let options: [ExerciseOptionIn]?
        let translations: [ExerciseTranslationIn]?

        enum CodingKeys: String, CodingKey {
            case exampleId = "example_id"
            case type
            case answer
            case options
            case translations
        }
    }

    // PUT /exercises/{id}/options
    struct OptionsReplaceRequest: Codable {
        let options: [ExerciseOptionIn]
    }

    // PUT /exercises/{id}/translations
    struct TranslationsReplaceRequest: Codable {
        let translations: [ExerciseTranslationIn]
    }

    // MARK: - Public API

    /// 목록 조회 (예문별 필터 가능)
    func list(exampleId: Int? = nil, limit: Int = 50) async throws -> [Exercise] {
        var query: [URLQueryItem] = [.init(name: "limit", value: "\(min(max(limit, 1), 200))")]
        if let exampleId { query.append(.init(name: "example_id", value: "\(exampleId)")) }
        return try await api.request("GET", "/exercises", query: query, as: [Exercise].self)
    }

    /// 단건 조회
    func get(id: Int) async throws -> Exercise {
        try await api.request("GET", "/exercises/\(id)", as: Exercise.self)
    }

    /// 생성
    @discardableResult
    func create(
        exampleId: Int,
        type: String,
        answer: String,
        options: [ExerciseOptionIn]? = nil,
        translations: [ExerciseTranslationIn]? = nil
    ) async throws -> Exercise {
        let body = ExerciseCreateRequest(
            exampleId: exampleId,
            type: type,
            answer: answer,
            options: options,
            translations: translations
        )
        return try await api.request("POST", "/exercises", jsonBody: body, as: Exercise.self)
    }

    /// 수정 (전달한 항목만 갱신, 옵션/번역은 전달 시 전체 치환)
    @discardableResult
    func update(
        id: Int,
        exampleId: Int? = nil,
        type: String? = nil,
        answer: String? = nil,
        options: [ExerciseOptionIn]? = nil,
        translations: [ExerciseTranslationIn]? = nil
    ) async throws -> Exercise {
        let body = ExerciseUpdateRequest(
            exampleId: exampleId,
            type: type,
            answer: answer,
            options: options,
            translations: translations
        )
        return try await api.request("PUT", "/exercises/\(id)", jsonBody: body, as: Exercise.self)
    }

    /// 삭제
    func delete(id: Int) async throws {
        _ = try await api.request("DELETE", "/exercises/\(id)", as: Empty.self)
    }

    /// 옵션만 일괄 치환
    @discardableResult
    func replaceOptions(exerciseId: Int, options: [ExerciseOptionIn]) async throws -> Exercise {
        let body = OptionsReplaceRequest(options: options)
        return try await api.request("PUT", "/exercises/\(exerciseId)/options", jsonBody: body, as: Exercise.self)
    }

    /// 번역만 일괄 치환
    @discardableResult
    func replaceTranslations(exerciseId: Int, translations: [ExerciseTranslationIn]) async throws -> Exercise {
        let body = TranslationsReplaceRequest(translations: translations)
        return try await api.request("PUT", "/exercises/\(exerciseId)/translations", jsonBody: body, as: Exercise.self)
    }
}


