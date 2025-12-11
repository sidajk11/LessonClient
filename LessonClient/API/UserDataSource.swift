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
    
    func me() async throws -> User { try await api.request("GET", "admin/users/me", as: User.self) }
    func register(email: String, password: String) async throws -> User {
        struct Body: Codable { let email: String; let password: String }
        return try await api.request("POST", "admin/users", jsonBody: Body(email: email, password: password), authorized: false, as: User.self)
    }
    
    func login(email: String, password: String) async throws {
        do {
            let res: TokenRes = try await api.request(
                "POST",
                "auth/login",
                formBody: [
                    "username": email,
                    "password": password,
                    "grant_type": "password",
                    "scope": ""
                ],
                authorized: false,
                as: TokenRes.self
            )
            api.accessToken = res.access_token
        } catch APIClient.APIError.http(let status, let raw) where status == 400 {
            // 서버 detail 메시지 뽑기
            if let data = raw?.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = obj["detail"] as? String {
                throw APIClient.APIError.http(status, detail)
            }
            throw APIClient.APIError.http(status, raw)
        }
    }
}

extension String {
    var capitalizedBearer: String {
        // 서버는 "bearer"를 보내지만 헤더에 "Bearer"로 쓰는 것이 관례
        self.lowercased() == "bearer" ? "Bearer" : self
    }
}
