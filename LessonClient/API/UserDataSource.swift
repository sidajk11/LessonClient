//
//  UserDataSource.swift
//  LessonClient
//
//  Created by ymj on 9/29/25.
//

import Foundation

final class UserDataSource {
    static let shared = UserDataSource()
    private let api = APIClient.shared
    private init() {}
    
    // MARK: Auth
    struct TokenRes: Codable { let access_token: String; let token_type: String }
    func login(email: String, password: String) async throws {
        let res: TokenRes = try await api.request("POST", "/auth/login",
            formBody: ["username": email, "password": password], authorized: false, as: TokenRes.self)
        api.accessToken = res.access_token
    }
    func me() async throws -> User { try await api.request("GET", "/users/me", as: User.self) }
    func register(email: String, password: String) async throws -> User {
        struct Body: Codable { let email: String; let password: String }
        return try await api.request("POST", "/users", jsonBody: Body(email: email, password: password), authorized: false, as: User.self)
    }
}
