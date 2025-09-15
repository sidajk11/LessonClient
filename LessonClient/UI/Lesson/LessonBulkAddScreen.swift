//
//  LessonBulkAddScreen.swift
//  LessonClient
//
//  Created by ymj on 9/9/25.
//

import SwiftUI

struct LessonBulkAddScreen: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: ((Lesson) -> Void)? = nil

    @State private var input = """
        1
        topic
        gramma
        
        bag^가방
        phone^휴대폰

        bag
        My bag and my phone.^내 가방과 내 휴대폰.

        phone
        My phone and my bag.^내 휴대폰과 내 가방.
        """
    @State private var parsed: BulkParsed?
    @State private var parsingError: String?
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("입력") {
                TextEditor(text: $input)
                    .frame(minHeight: 220)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)

                HStack {
                    Button("미리보기") { parseNow() }
                    Spacer()
                    Button(saving ? "생성 중…" : "생성") {
                        Task { await createAll() }
                    }
                    .disabled(saving)
                    .buttonStyle(.borderedProminent)
                }

                if let parsingError {
                    Text(parsingError).foregroundStyle(.red)
                }
            }

            if let p = parsed {
                Section("요약") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Level: \(p.level)")
                        if let t = p.topic, !t.isEmpty { Text("Topic: \(t)") }
                        if let g = p.grammar, !g.isEmpty { Text("Main Grammar: \(g)") }
                        Text("단어 \(p.words.count)개, 표현 \(p.expressions.count)개")
                        Text("예문 총 \(p.expressions.map{ $0.examples.count }.reduce(0,+))개")
                    }
                }
                Section("표현 미리보기 (일부)") {
                    ForEach(p.expressions.prefix(5)) { e in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• \(e.text)").bold()
                            if !e.meanings.isEmpty {
                                Text("뜻: \(e.meanings.joined(separator: ", "))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(e.examples.prefix(2), id: \.id) { ex in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.en)
                                    if let ko = ex.ko { Text(ko).foregroundStyle(.secondary).font(.footnote) }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("레슨 일괄추가")
        .onAppear(perform: parseNow)
    }

    private func parseNow() {
        do {
            parsed = try BulkParser.parse(input)
            parsingError = nil
        } catch {
            parsed = nil
            parsingError = error.localizedDescription
        }
    }

    private func createAll() async {
        guard let p = parsed else {
            parseNow()
            if parsed == nil { return }
            return
        }
        saving = true
        defer { saving = false }

        do {
            // 1) 레슨 생성
            let lesson = try await APIClient.shared.createLesson(
                name: p.title ?? "",
                level: p.level,
                topic: p.topic?.nilIfBlank,
                grammar: p.grammar?.nilIfBlank
            )

            // 2) 단어 생성 & 연결
            for w in p.words {
                let meanings = w.meanings.isEmpty ? [w.text] : w.meanings
                let newWord = try await APIClient.shared.createWord(text: w.text, meanings: meanings)
                try await APIClient.shared.attachWord(lessonId: lesson.id, wordId: newWord.id)
            }

            // 3) 표현 생성 & 연결 + 4) 예문 추가
            for e in p.expressions {
                let meanings = e.meanings.isEmpty ? [e.text] : e.meanings
                let expr = try await APIClient.shared.createExpression(text: e.text, meanings: meanings)
                try await APIClient.shared.attachExpression(lessonId: lesson.id, expressionId: expr.id)

                for ex in e.examples {
                    _ = try await APIClient.shared.addExampleToExpression(
                        exprId: expr.id,
                        en: ex.en,
                        ko: ex.ko?.nilIfBlank
                    )
                }
            }

            // 완료
            onCreated?(lesson)
            dismiss()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

// MARK: - 파서 & 모델

fileprivate struct BulkParsed {
    struct WordSpec: Identifiable { var id = UUID(); let text: String; let meanings: [String] }
    struct ExampleSpec: Identifiable { var id = UUID(); let en: String; let ko: String? }
    struct ExprSpec: Identifiable {
        var id = UUID()
        let text: String
        let meanings: [String]
        var examples: [ExampleSpec]
    }

    let title: String?
    let level: Int
    let topic: String?
    let grammar: String?
    let words: [WordSpec]
    let expressions: [ExprSpec]
}

fileprivate enum BulkParser {
    static func parse(_ raw: String) throws -> BulkParsed? {
        if let p = try? parseNewFormat(raw) { return p }
        return nil//try parseOldFormats(raw) // ← 기존 구현을 이 함수로 이동
    }

    // MARK: - 새 포맷 파서
    private static func parseNewFormat(_ raw: String) throws -> BulkParsed {
        let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { String($0).trimmed }

        var i = 0
        func skipBlanks() { while i < lines.count && lines[i].isEmpty { i += 1 } }

        // 1) header: level / topic / main grammar
        skipBlanks()
        guard i < lines.count, let level = Int(lines[i]) else {
            throw NSError(domain: "BulkParser", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "첫 줄에 level(정수) 을 입력해 주세요."])
        }
        i += 1
        skipBlanks()
        guard i < lines.count else { throw err("둘째 줄에 topic을 입력해 주세요.") }
        let topic = lines[i]; i += 1
        skipBlanks()
        guard i < lines.count else { throw err("셋째 줄에 main grammar를 입력해 주세요.") }
        let grammar = lines[i]; i += 1

        // 2) 빈 줄 스킵
        skipBlanks()

        // 3) expressions 라인들: "text^뜻1/뜻2" ... 빈 줄 만날 때까지
        var exprsDict: [String: BulkParsed.ExprSpec] = [:]
        while i < lines.count, !lines[i].isEmpty {
            let line = lines[i]; i += 1
            let (textRaw, meaningRaw) = line.splitOnce("^") ?? (line, "")
            let text = textRaw.trimmed
            let meanings = meaningRaw
                .split(whereSeparator: { ",/".contains($0) })
                .map { String($0).trimmed }
                .filter { !$0.isEmpty }
            exprsDict[text] = BulkParsed.ExprSpec(text: text, meanings: meanings, examples: [])
        }

        // expressions에서 미리 알 수 있는 제목 집합
        var knownKeys = Set(exprsDict.keys)

        // 4) 빈 줄 스킵
        skipBlanks()

        // 5) 예문 블록들:
        //    "표현제목" 한 줄 → 그 아래 예문 여러 줄(EN.^KO. 또는 EN만) → 빈 줄 또는 다음 제목에서 종료
        while i < lines.count {
            skipBlanks()
            guard i < lines.count else { break }
            let key = lines[i]
            guard !key.isEmpty else { i += 1; continue }
            i += 1 // 제목 소비

            if exprsDict[key] == nil {
                exprsDict[key] = BulkParsed.ExprSpec(text: key, meanings: [], examples: [])
                knownKeys.insert(key)
            }

            // 예문 수집 루프
            while i < lines.count {
                let line = lines[i]
                if line.isEmpty { // 블록 종료
                    i += 1
                    break
                }
                // 다음 제목으로 판단: 미리 알던 제목이 나타났거나,
                // '^' 없는 줄이면서 그 다음 줄이 예문(보통 '^' 포함)으로 보이는 경우
                if knownKeys.contains(line) ||
                   (!line.contains("^") && (i + 1 < lines.count && lines[i + 1].contains("^"))) {
                    break
                }

                // 예문으로 처리
                let (enRaw, koRaw) = line.splitOnce("^") ?? (line, nil)
                let en = enRaw.trimmed.trimPeriods()
                let ko = koRaw?.trimmed.trimPeriods()
                exprsDict[key]!.examples.append(.init(en: en, ko: ko))
                i += 1
            }
        }

        // words = expressions와 동일
        let words = exprsDict.values.map { BulkParsed.WordSpec(text: $0.text, meanings: $0.meanings) }
        let exprs = Array(exprsDict.values)

        return BulkParsed(
            title: nil,
            level: level,
            topic: topic.nilIfBlank,
            grammar: grammar.nilIfBlank,
            words: words,
            expressions: exprs
        )
    }

    // MARK: - 기존 포맷 파서 (당신이 이전에 쓰던 구현을 이 함수로 옮겨두세요)
    private static func parseOldFormats(_ raw: String) throws -> BulkParsed {
        // === 기존 BulkParser.parse 내용 붙여넣기 ===
        // (이전 답변에서 드렸던 간단/명시적 포맷 파싱 구현 전체를 이 함수에 이동)
        fatalError("parseOldFormats(_: ) not implemented. 이전 구현을 여기로 옮겨 주세요.")
    }

    // 헬퍼
    private static func err(_ msg: String) -> NSError {
        NSError(domain: "BulkParser", code: 11, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: - 유틸

fileprivate extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : self }
    func trimPeriods() -> String {
        var s = self
        while s.hasSuffix(".") { s.removeLast() }
        return s.trimmed
    }
    func splitOnce(_ sep: String) -> (lhs: String, rhs: String)? {
        guard let r = range(of: sep) else { return nil }
        let left = String(self[..<r.lowerBound])
        let right = String(self[r.upperBound...])
        return (left, right)
    }
}

fileprivate extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
