import XCTest
@testable import LessonClientCore

final class ParityURLProtocol: URLProtocol {
    static var responseData = Data("[]".utf8)
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "parity.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ParityTests: XCTestCase {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    var fixtures: [String: Any] = [:]
    var previousURL: URL!
    var previousArguments: [String: Any] = [:]
    override func setUpWithError() throws {
        fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("parity/fixtures.json"))) as! [String: Any]
        previousURL = APIClient.shared.baseURL
        APIClient.shared.baseURL = URL(string: "https://parity.invalid")!
        previousArguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        UserDefaults.standard.setVolatileDomain(previousArguments.merging(["access_token": "mock-token"]) { _, new in new }, forName: UserDefaults.argumentDomain)
        URLProtocol.registerClass(ParityURLProtocol.self)
        ParityURLProtocol.requests = []
    }
    override func tearDownWithError() throws {
        APIClient.shared.baseURL = previousURL
        UserDefaults.standard.setVolatileDomain(previousArguments, forName: UserDefaults.argumentDomain)
        URLProtocol.unregisterClass(ParityURLProtocol.self)
    }
    func data(_ key: String) throws -> Data { try JSONSerialization.data(withJSONObject: fixtures[key]!) }
    func decode<T: Decodable>(_ type: T.Type, _ key: String) throws -> T { try JSONDecoder.lessonClient.decode(type, from: data(key)) }
    func reply(_ value: Any) throws { ParityURLProtocol.responseData = try JSONSerialization.data(withJSONObject: value) }
    func capture(_ method: String, _ path: String) throws {
        let request = try XCTUnwrap(ParityURLProtocol.requests.last)
        XCTAssertEqual(request.httpMethod, method); XCTAssertEqual(request.url?.path, path)
        XCTAssertEqual(request.url?.host, "parity.invalid")
    }
    func canonicalRequest() -> [String: Any] {
        let request = ParityURLProtocol.requests.last!
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        var result: [String: Any] = ["method": request.httpMethod!, "path": components.path,
                "query": Dictionary(components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { _, b in b })]
        if let bytes = Self.bodyData(request), var body = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any] {
            // Server defaults these to an empty list; compare equivalent payloads.
            if components.path == "/admin/lessons/insert", body["vocabulary_ids"] == nil { body["vocabulary_ids"] = [] }
            result["body"] = body
        }
        return result
    }

    func testReadContractsAcrossAllAdminResources() async throws {
        try reply([fixtures["lesson"]!]); _ = try await LessonDataSource.shared.lessons(unit: 10, limit: 100); try capture("GET", "/admin/lessons")
        try reply([fixtures["vocabulary"]!]); _ = try await VocabularyDataSource.shared.searchVocabularys(q: "cat", limit: 100); try capture("GET", "/admin/vocabularies/search")
        try reply([fixtures["example"]!]); _ = try await ExampleDataSource.shared.search(q: "cat", limit: 50); try capture("GET", "/admin/examples/search")
        try reply([fixtures["sentence"]!]); _ = try await ExampleSentenceDataSource.shared.searchExampleSentences(q: "cat", limit: 400); try capture("GET", "/admin/example-sentences/search")
        try reply([fixtures["unit_level"]!]); _ = try await UnitLevelDataSource.shared.listUnitLevels(); try capture("GET", "/admin/unit-levels")
        try reply([fixtures["exercise"]!]); _ = try await ExerciseDataSource.shared.search(q: "cat"); try capture("GET", "/admin/exercises/search")
        try reply([fixtures["queue"]!]); _ = try await ExerciseQueueDataSource.shared.listExerciseQueues(); try capture("GET", "/admin/exercise-queues")
        try reply([fixtures["state"]!]); _ = try await UserVocabularyStateDataSource.shared.listUserVocabularyStates(); try capture("GET", "/admin/user-vocabulary-states")
        try reply([fixtures["word"]!]); _ = try await WordDataSource.shared.listWords(); try capture("GET", "/admin/words")
        try reply([fixtures["form"]!]); _ = try await WordFormDataSource.shared.listWordForms(); try capture("GET", "/admin/word-forms")
        try reply([fixtures["phrase"]!]); _ = try await PhraseDataSource.shared.listPhrases(); try capture("GET", "/admin/phrases")
        try reply([fixtures["pronunciation"]!]); _ = try await PronunciationDataSource.shared.listPronunciations(); try capture("GET", "/admin/pronunciations")
        try reply(fixtures["sense"]!); _ = try await WordDataSource.shared.wordSense(senseId: 5); try capture("GET", "/admin/words/senses/5")
        XCTAssertEqual(ParityURLProtocol.requests.count, 13)
    }
    func testMutationContractsAreInterceptedWithoutServerWrites() async throws {
        try reply(fixtures["example"]!)
        _ = try await ExampleDataSource.shared.attachExampleToVocabulary(exampleId: 3, vocabularyId: 7)
        try capture("PUT", "/admin/examples/3")
        _ = try await ExampleDataSource.shared.detachExampleFromVocabulary(id: 3)
        try capture("PUT", "/admin/examples/3")
        try reply([:])
        try await ExampleSentenceDataSource.shared.deleteExampleSentence(id: 4)
        try capture("DELETE", "/admin/example-sentences/4")
    }
    func testSharedModelFixturesAndSnapshot() async throws {
        var snapshot: [String: Any] = [:]
        let lesson = try decode(Lesson.self, "lesson")
        snapshot["lesson.unit"] = lesson.unit
        snapshot["lesson.korean_topic"] = lesson.translations.koText()
        snapshot["vocabulary.korean"] = try decode(Vocabulary.self, "vocabulary").translations.koText()
        snapshot["sentence.text"] = try decode(ExampleSentence.self, "sentence").text
        snapshot["exercise.prompt"] = try decode(Exercise.self, "exercise").displayPrompt
        snapshot["exercise.type"] = try decode(Exercise.self, "exercise").type == .combine ? "combine" : "other"
        snapshot["option.raw_display"] = try decode(ExerciseOption.self, "option").displayText
        snapshot["option.language_priority"] = try decode(ExerciseOption.self, "option_language_order").displayText
        snapshot["tokens.currency"] = (fixtures["tokens"] as! [String]).joinTokens()
        snapshot["tokens.parentheses"] = (fixtures["parenthesis_tokens"] as! [String]).joinTokens()
        snapshot["tokens.contractions"] = (fixtures["tokenize"] as! String).tokenize()
        for key in ["sense_valid", "sense_without_example", "sense_empty_pos"] {
            snapshot["parser.\(key)"] = (try? SenseBulkParser.parse(fixtures[key] as! String)) == nil ? "rejected" : "accepted"
        }
        do { let attempt = try decode(ExerciseAttemptRead.self, "attempt"); snapshot["attempt.current_response"] = attempt.isCorrect ? "correct" : "wrong" }
        catch { snapshot["attempt.current_response"] = "decode_error" }
        // Capture filter construction independently from the changed response schema.
        try reply([])
        _ = try await ExerciseAttemptDataSource.shared.listExerciseAttempts(userId: 1, isCorrect: true)
        snapshot["request.attempt_filter"] = canonicalRequest()
        try reply(fixtures["lesson"]!)
        _ = try await LessonDataSource.shared.insertLesson(unit: 10)
        snapshot["request.lesson_insert"] = canonicalRequest()
        try reply(fixtures["example"]!)
        _ = try await ExampleDataSource.shared.attachExampleToVocabulary(exampleId: 3, vocabularyId: 7)
        snapshot["request.example_attach"] = canonicalRequest()
        try reply(["access_token": "mock-login-token", "token_type": "bearer"])
        let credentials = fixtures["login"] as! [String: String]
        // request() exercises the production form encoder without persisting a token.
        let _: [String: String] = try await APIClient.shared.request("POST", "app/v1/auth/login", formBody: ["username": credentials["username"]!, "password": credentials["password"]!, "grant_type": "password", "scope": ""], authorized: false, as: [String: String].self)
        let request = ParityURLProtocol.requests.last!
        let formData = Self.bodyData(request)
        snapshot["login.decoded_fields"] = Self.decodeForm(String(data: formData ?? Data(), encoding: .utf8) ?? "")
        let output = ProcessInfo.processInfo.environment["PARITY_OUTPUT_FILE"] ?? root.appendingPathComponent("parity/results/swift.json").path
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: output).deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: output))
        XCTAssertEqual(snapshot["lesson.unit"] as? Int, 10)
        XCTAssertEqual(snapshot["parser.sense_valid"] as? String, "accepted")
    }
    static func bodyData(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096); var bytes = Data()
        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; bytes.append(buffer, count: count) }
        return bytes
    }
    static func decodeForm(_ raw: String) -> [String: String] {
        var output: [String: String] = [:]
        for part in raw.split(separator: "&", omittingEmptySubsequences: false) {
            let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2 else { continue }
            output[String(pieces[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""] = String(pieces[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""
        }
        return output
    }
}
