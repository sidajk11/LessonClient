//
//  OpenAIClient.swift
//  LessonClient
//
//  Created by ym on 2/25/26.
//

import Foundation

final class OpenAIClient {
    private let apiKey: String = ""
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API
    func generateText(prompt: String, model: String = "gpt-5.4") async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/responses")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") // Bearer auth :contentReference[oaicite:3]{index=3}
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ResponseCreateRequest(
            model: model,
            input: [
                .message(role: "user", content: prompt)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            // 에러 바디를 그대로 보여주면 디버깅에 좋아요
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError.http(statusCode: http.statusCode, body: text)
        }

        let decoded = try JSONDecoder().decode(ResponseCreateResponse.self, from: data)

        // 문서/SDK에서 response.output_text를 제공 :contentReference[oaicite:4]{index=4}
        // 실제 JSON에도 output_text가 포함되는 경우가 많아 우선 사용하고,
        // 없으면 output 배열에서 텍스트를 합치는 fallback을 둡니다.
        if let outputText = decoded.output_text, !outputText.isEmpty {
            return outputText
        }

        let fallback = decoded.output?
            .compactMap { $0.content }
            .flatMap { $0 }
            .compactMap { $0.text }
            .joined(separator: "")

        return fallback ?? ""
    }
}

// MARK: - Models
private struct ResponseCreateRequest: Encodable {
    let model: String
    let input: [InputItem]

    enum InputItem: Encodable {
        case message(role: String, content: String)

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .message(let role, let content):
                try container.encode(role, forKey: .role)
                try container.encode(content, forKey: .content)
            }
        }

        enum CodingKeys: String, CodingKey {
            case role, content
        }
    }
}

private struct ResponseCreateResponse: Decodable {
    let id: String?
    let output_text: String?
    let output: [OutputItem]?

    struct OutputItem: Decodable {
        let content: [ContentItem]?
    }

    struct ContentItem: Decodable {
        let type: String?
        let text: String?
    }
}

enum OpenAIError: Error, LocalizedError {
    case http(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            return "OpenAI API HTTP \(code)\n\(body)"
        }
    }
}
