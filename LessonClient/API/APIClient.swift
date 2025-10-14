// APIClient.swift
import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    //var baseURL: URL = URL(string: "http://34.64.239.171:8000")!
    var baseURL: URL = URL(string: "http://127.0.0.1:8000")!

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "access_token") }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: "access_token") }
            else { UserDefaults.standard.removeObject(forKey: "access_token") }
        }
    }

    enum APIError: Error, LocalizedError {
        case badURL
        case http(Int, String?)
        case decoding
        case unknown

        var errorDescription: String? {
            switch self {
            case .badURL: return "잘못된 URL"
            case .decoding: return "응답 해석 실패"
            case let .http(code, msg): return "HTTP \(code): \(msg ?? "오류")"
            case .unknown: return "알 수 없는 오류"
            }
        }
    }

    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem]? = nil,
        jsonBody: Encodable? = nil,
        formBody: [String:String]? = nil,
        authorized: Bool = true,
        as type: T.Type
    ) async throws -> T {
        var comp = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if let query = query { comp.queryItems = query }
        guard let url = comp.url else { throw APIError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        
        print("request: \(req)")

        if let form = formBody {
            req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let body = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                           .joined(separator: "&")
            req.httpBody = body.data(using: .utf8)
            print("body: \(body)")
        } else if let body = jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            print("body: \(body)")
        }

        if authorized, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.unknown }
        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8)
            throw APIError.http(http.statusCode, msg)
        }
        if T.self == Empty.self { return Empty() as! T }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

/// JSON Encodable wrapper
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
