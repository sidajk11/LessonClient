// APIClient.swift
import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    var baseURL: URL = URL(string: "http://34.64.239.171:8000")!

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

    private func request<T: Decodable>(
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

        if let form = formBody {
            req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let body = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                           .joined(separator: "&")
            req.httpBody = body.data(using: .utf8)
        } else if let body = jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
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

    // MARK: Auth
    struct TokenRes: Codable { let access_token: String; let token_type: String }
    func login(email: String, password: String) async throws {
        // OAuth2PasswordRequestForm: username=email, password=...
        let res: TokenRes = try await request("POST", "/auth/login",
            formBody: ["username": email, "password": password], authorized: false, as: TokenRes.self)
        accessToken = res.access_token
    }
    func me() async throws -> User {
        try await request("GET", "/users/me", as: User.self)
    }
    func register(email: String, password: String) async throws -> User {
        struct Body: Codable { let email: String; let password: String }
        return try await request("POST", "/users", jsonBody: Body(email: email, password: password), authorized: false, as: User.self)
    }

    // MARK: Lessons
    
    func createLesson(name: String, level: Int, topic: String?, grammar: String?) async throws -> Lesson {
        struct Body: Codable {
            let name: String
            let level: Int
            let topic: String?
            let grammar_main: String?
        }
        let body = Body(name: name, level: level, topic: topic, grammar_main: grammar)
        return try await request("POST", "/lessons", jsonBody: body, as: Lesson.self)
    }

    func lessons() async throws -> [Lesson] {
        try await request("GET", "/lessons", as: [Lesson].self)
    }
    func lesson(id: Int) async throws -> Lesson {
        try await request("GET", "/lessons/\(id)", as: Lesson.self)
    }
    func updateLesson(id: Int, payload: Lesson) async throws -> Lesson {
        struct Body: Codable {
            let id: Int
            var name: String
            var level: Int
            var topic: String?
            var grammar_main: String?
            var word_ids: [Int]?
        }
        var word_ids: [Int]?
        if let words = payload.words {
            word_ids = words.map { $0.id }
        }
        
        let body = Body(id: payload.id, name: payload.name, level: payload.level, grammar_main: payload.grammar_main, word_ids: word_ids)
        return try await request("PUT", "/lessons/\(id)", jsonBody: body, as: Lesson.self)
    }
    
    func deleteLesson(id: Int) async throws { _ = try await request("DELETE", "/lessons/\(id)", as: Empty.self) }
    func attachWord(lessonId: Int, wordId: Int) async throws { struct Body: Codable { let word_id: Int }
        _ = try await request("POST", "/lessons/\(lessonId)/words", jsonBody: Body(word_id: wordId), as: Empty.self)
    }
    func detachWord(lessonId: Int, wordId: Int) async throws {
        _ = try await request("DELETE", "/lessons/\(lessonId)/words/\(wordId)", as: Empty.self)
    }

    // MARK: Words
    func words() async throws -> [Word] { try await request("GET", "/words", as: [Word].self) }
    func word(id: Int) async throws -> Word { try await request("GET", "/words/\(id)", as: Word.self) }
    func createWord(text: String, meanings: [String]) async throws -> Word {
        struct Body: Codable { let text: String; let meanings: [String] }
        return try await request("POST", "/words", jsonBody: Body(text: text, meanings: meanings), as: Word.self)
    }
    func updateWord(id: Int, text: String, meanings: [String]) async throws -> Word {
        struct Body: Codable { let text: String; let meanings: [String] }
        return try await request("PUT", "/words/\(id)", jsonBody: Body(text: text, meanings: meanings), as: Word.self)
    }
    func deleteWord(id: Int) async throws { _ = try await request("DELETE", "/words/\(id)", as: Empty.self) }
    func searchWords(q: String, limit: Int = 20) async throws -> [Word] {
        try await request("GET", "/words/search", query: [.init(name: "q", value: q), .init(name: "limit", value: "\(limit)")], as: [Word].self)
    }
    func wordByText(_ t: String) async throws -> Word {
        try await request("GET", "/words/by-text/\(t.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)", as: Word.self)
    }

    // MARK: Examples
    func examples(wordId: Int) async throws -> [ExampleItem] {
        try await request("GET", "/words/\(wordId)/examples", as: [ExampleItem].self)
    }
    func createExample(wordId: Int, en: String, ko: String?) async throws -> ExampleItem {
        struct Body: Codable { let sentence_en: String; let translation_ko: String? }
        return try await request("POST", "/words/\(wordId)/examples", jsonBody: Body(sentence_en: en, translation_ko: ko), as: ExampleItem.self)
    }
    func updateExample(exampleId: Int, en: String, ko: String?) async throws -> ExampleItem {
        struct Body: Codable { let sentence_en: String; let translation_ko: String? }
        return try await request("PUT", "/words/examples/\(exampleId)", jsonBody: Body(sentence_en: en, translation_ko: ko), as: ExampleItem.self)
    }
    func deleteExample(exampleId: Int) async throws { _ = try await request("DELETE", "/words/examples/\(exampleId)", as: Empty.self) }

    // MARK: Global Example Search
    struct ExampleRow: Codable, Identifiable {
        let id: Int
        let word_id: Int
        let sentence_en: String
        let translation_ko: String?
        let word_text: String
    }
    func searchExamples(q: String, limit: Int = 20) async throws -> [ExampleRow] {
        try await request("GET", "/examples/search", query: [.init(name: "q", value: q), .init(name: "limit", value: "\(limit)")], as: [ExampleRow].self)
    }
}

struct Empty: Codable {}

/// JSON Encodable wrapper
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
