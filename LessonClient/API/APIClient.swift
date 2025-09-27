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
        let res: TokenRes = try await request("POST", "/auth/login",
            formBody: ["username": email, "password": password], authorized: false, as: TokenRes.self)
        accessToken = res.access_token
    }
    func me() async throws -> User { try await request("GET", "/users/me", as: User.self) }
    func register(email: String, password: String) async throws -> User {
        struct Body: Codable { let email: String; let password: String }
        return try await request("POST", "/users", jsonBody: Body(email: email, password: password), authorized: false, as: User.self)
    }

    // MARK: Lessons
    func createLesson(name: String, unit: Int, level: Int, topic: String?, grammar: String?) async throws -> Lesson {
        struct Body: Codable {
            let name: String
            let unit: Int
            let level: Int
            let topic: String?
            let grammar_main: String?
        }
        let body = Body(name: name, unit: unit, level: level, topic: topic, grammar_main: grammar)
        return try await request("POST", "/lessons", jsonBody: body, as: Lesson.self)
    }

    func lessons(levelMin: Int? = nil, levelMax: Int? = nil) async throws -> [Lesson] {
        var query: [URLQueryItem] = []
        if let levelMin { query.append(.init(name: "level_min", value: "\(levelMin)")) }
        if let levelMax { query.append(.init(name: "level_max", value: "\(levelMax)")) }
        return try await request("GET", "/lessons", query: query.isEmpty ? nil : query, as: [Lesson].self)
    }
    func lesson(id: Int) async throws -> Lesson {
        try await request("GET", "/lessons/\(id)", as: Lesson.self)
    }

    func updateLesson(id: Int, payload: Lesson) async throws -> Lesson {
        struct Body: Codable {
            let id: Int
            var name: String
            var unit: Int
            var level: Int
            var topic: String?
            var grammar_main: String?
            var expression_ids: [Int]?
            var word_ids: [Int]?
        }
        var word_ids: [Int]?
        if let words = payload.words {
            word_ids = words.map { $0.id }
        }
        var expression_ids: [Int]?
        if let expressions = payload.expressions {
            expression_ids = expressions.map { $0.id }
        }
        let body = Body(
            id: payload.id,
            name: payload.name,
            unit: payload.unit,
            level: payload.level,
            topic: payload.topic,
            grammar_main: payload.grammar_main,
            expression_ids: expression_ids,
            word_ids: word_ids
        )
        return try await request("PUT", "/lessons/\(id)", jsonBody: body, as: Lesson.self)
    }
    func deleteLesson(id: Int) async throws { _ = try await request("DELETE", "/lessons/\(id)", as: Empty.self) }

    @discardableResult
    func attachWord(lessonId: Int, wordId: Int) async throws -> Lesson {
        struct Body: Codable { let word_id: Int }
        return try await request("POST", "/lessons/\(lessonId)/words", jsonBody: Body(word_id: wordId), as: Lesson.self)
    }
    @discardableResult
    func detachWord(lessonId: Int, wordId: Int) async throws -> Lesson {
        try await request("DELETE", "/lessons/\(lessonId)/words/\(wordId)", as: Lesson.self)
    }

    @discardableResult
    func attachExpression(lessonId: Int, expressionId: Int) async throws -> Lesson {
        struct Body: Codable { let expression_id: Int }
        return try await request("POST", "/lessons/\(lessonId)/expressions", jsonBody: Body(expression_id: expressionId), as: Lesson.self)
    }
    @discardableResult
    func detachExpression(lessonId: Int, expressionId: Int) async throws -> Lesson {
        try await request("DELETE", "/lessons/\(lessonId)/expressions/\(expressionId)", as: Lesson.self)
    }
    @discardableResult
    func reorderExpressions(lessonId: Int, expressionIds: [Int]) async throws -> Lesson {
        struct Body: Codable { let ids: [Int] }
        return try await request("PUT", "/lessons/\(lessonId)/expressions/order", jsonBody: Body(ids: expressionIds), as: Lesson.self)
    }

    // MARK: Words (lang-aware)
    func words(lang: String = "ko") async throws -> [Word] {
        try await request("GET", "/words", query: [.init(name: "lang", value: lang)], as: [Word].self)
    }
    func word(id: Int, lang: String = "ko") async throws -> Word {
        try await request("GET", "/words/\(id)", query: [.init(name: "lang", value: lang)], as: Word.self)
    }
    func createWord(text: String, meanings: [String], lang: String = "ko") async throws -> Word {
        struct Body: Codable { let text: String; let meanings: [String] }
        return try await request("POST", "/words",
                                 query: [.init(name: "lang", value: lang)],
                                 jsonBody: Body(text: text, meanings: meanings),
                                 as: Word.self)
    }
    func updateWord(id: Int, text: String, meanings: [String], lang: String = "ko") async throws -> Word {
        struct Body: Codable { let text: String; let meanings: [String] }
        return try await request("PUT", "/words/\(id)",
                                 query: [.init(name: "lang", value: lang)],
                                 jsonBody: Body(text: text, meanings: meanings),
                                 as: Word.self)
    }
    func deleteWord(id: Int) async throws { _ = try await request("DELETE", "/words/\(id)", as: Empty.self) }

    func searchWords(q: String, level: Int? = nil, limit: Int = 20, lang: String = "ko") async throws -> [Word] {
        var query: [URLQueryItem] = [
            .init(name: "q", value: q),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "lang", value: lang)
        ]
        if let level { query.append(.init(name: "level", value: "\(level)")) }
        return try await request("GET", "/words/search", query: query, as: [Word].self)
    }

    func wordByText(_ t: String, lang: String = "ko") async throws -> Word {
        try await request(
            "GET",
            "/words/by-text/\(t.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)",
            query: [.init(name: "lang", value: lang)],
            as: Word.self
        )
    }

    // MARK: Expressions (lang-aware)
    func expressions(lang: String = "ko") async throws -> [Expression] {
        try await request("GET", "/expressions", query: [.init(name: "lang", value: lang)], as: [Expression].self)
    }

    func expression(id: Int, lang: String = "ko") async throws -> Expression {
        try await request("GET", "/expressions/\(id)", query: [.init(name: "lang", value: lang)], as: Expression.self)
    }

    func createExpression(text: String, meanings: [String], lang: String = "ko") async throws -> Expression {
        struct Body: Codable { let text: String; let meanings: [String] }
        return try await request("POST", "/expressions",
                                 query: [.init(name: "lang", value: lang)],
                                 jsonBody: Body(text: text, meanings: meanings),
                                 as: Expression.self)
    }

    func updateExpression(id: Int, text: String, meanings: [String], lang: String = "ko") async throws -> Expression {
        struct Body: Codable { let text: String; let meanings: [String] }
        return try await request("PUT", "/expressions/\(id)",
                                 query: [.init(name: "lang", value: lang)],
                                 jsonBody: Body(text: text, meanings: meanings),
                                 as: Expression.self)
    }

    func deleteExpression(id: Int) async throws {
        _ = try await request("DELETE", "/expressions/\(id)", as: Empty.self)
    }

    func expressionsOfLesson(lessonId: Int, lang: String = "ko") async throws -> Lesson {
        try await request("GET", "/expressions/by-lesson/\(lessonId)",
                          query: [.init(name: "lang", value: lang)],
                          as: Lesson.self)
    }
    
    func searchExpressions(q: String, level: Int? = nil, limit: Int = 20) async throws -> [Expression] {
        var query: [URLQueryItem] = [
            .init(name: "q", value: q),
            .init(name: "limit", value: "\(limit)")
        ]
        if let level {
            query.append(.init(name: "level", value: "\(level)"))
        }
        return try await request("GET", "/expressions/search", query: query, as: [Expression].self)
    }
    
    func unassignedExpressions(q: String = "", limit: Int = 20) async throws -> [Expression] {
        try await request(
            "GET", "/expressions/unassigned",
            query: [.init(name: "q", value: q), .init(name: "limit", value: "\(limit)")],
            as: [Expression].self
        )
    }

    func examples(expressionId: Int, lang: String = "ko") async throws -> [ExampleItem] {
        try await request("GET",
                          "/expressions/\(expressionId)/examples",
                          query: [.init(name: "lang", value: lang)],
                          as: [ExampleItem].self)
    }

    func createExample(expressionId: Int, sentenceEN: String, translation: String?, lang: String = "ko") async throws -> ExampleItem {
        struct Body: Codable { let sentence_en: String; let translation: String? }
        return try await request("POST",
                                 "/expressions/\(expressionId)/examples",
                                 query: [.init(name: "lang", value: lang)],
                                 jsonBody: Body(sentence_en: sentenceEN, translation: translation),
                                 as: ExampleItem.self)
    }

    func updateExample(exampleId: Int, sentenceEN: String, translation: String?, lang: String = "ko") async throws -> ExampleItem {
        struct Body: Codable { let sentence_en: String; let translation: String? }
        return try await request("PUT",
                                 "/expressions/examples/\(exampleId)",
                                 query: [.init(name: "lang", value: lang)],
                                 jsonBody: Body(sentence_en: sentenceEN, translation: translation),
                                 as: ExampleItem.self)
    }

    func deleteExample(exampleId: Int) async throws {
        _ = try await request("DELETE", "/expressions/examples/\(exampleId)", as: Empty.self)
    }

    // MARK: Global Example Search (lang-aware)
    struct ExampleRow: Codable, Identifiable {
        let id: Int
        let expression_id: Int
        let sentence_en: String
        let translation: String?
        let expression_text: String
        let lang: String
    }

    func searchExamples(q: String, level: Int? = nil, limit: Int = 20, lang: String = "ko") async throws -> [ExampleRow] {
        var query: [URLQueryItem] = [
            .init(name: "q", value: q),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "lang", value: lang)
        ]
        if let level {
            query.append(.init(name: "level", value: "\(level)"))
        }
        return try await request("GET", "/examples/search", query: query, as: [ExampleRow].self)
    }

    // ===== (Deprecated) ko-고정 호환 래퍼 =====
    @available(*, deprecated, message: "Use createExample(expressionId:sentenceEN:translation:lang:) instead.")
    func addExampleToExpression(exprId: Int, en: String, ko: String?) async throws -> ExampleItem {
        try await createExample(expressionId: exprId, sentenceEN: en, translation: ko, lang: "ko")
    }

    @available(*, deprecated, message: "Use createExample(expressionId:sentenceEN:translation:lang:) instead.")
    func createExample(expressionId: Int, en: String, ko: String?) async throws -> ExampleItem {
        try await createExample(expressionId: expressionId, sentenceEN: en, translation: ko, lang: "ko")
    }

    @available(*, deprecated, message: "Use updateExample(exampleId:sentenceEN:translation:lang:) instead.")
    func updateExample(exampleId: Int, en: String, ko: String?) async throws -> ExampleItem {
        try await updateExample(exampleId: exampleId, sentenceEN: en, translation: ko, lang: "ko")
    }
}

struct Empty: Codable {}

/// JSON Encodable wrapper
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
