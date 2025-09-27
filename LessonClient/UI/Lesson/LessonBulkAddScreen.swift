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
        3
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
                        Text("Unit: \(p.unit)")
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
        
        guard !saving else {
            return
        }
        
        saving = true
        defer { saving = false }

        do {
            // 1) 레슨 생성 (unit 추가)
            let lesson = try await APIClient.shared.createLesson(
                name: p.title ?? "",
                unit: p.unit,
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
                let meanings = e.meanings.isEmpty ? [""] : e.meanings
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
    let unit: Int                   // ← 추가
    let topic: String?
    let grammar: String?
    let words: [WordSpec]
    let expressions: [ExprSpec]
}

fileprivate enum BulkParser {
    static func parse(_ raw: String) throws -> BulkParsed? {
        if let p = try? parseNewFormat(raw) { return p }
        return nil//try parseOldFormats(raw)
    }

    // === JSON 입력 스키마 ===
    private struct Root: Decodable {
        let level: Int
        let unit: Int?
        let topic: String?
        let grammar: String?
        let expressions: [String: [String: String]]?
        let example: [String: [String: String]]?
    }

    // === 메인: JSON 파서 ===
    private func parseNewJSON(_ raw: String) throws -> BulkParsed {
        let data = Data(raw.utf8)
        let decoder = JSONDecoder()
        let root = try decoder.decode(Root.self, from: data)

        // 1) 기본 필드
        let level = root.level
        let unit = root.unit ?? 1
        let topic = root.topic?.nilIfBlank()
        let grammar = root.grammar?.nilIfBlank()

        // 2) expressions -> ExprSpec
        //    meanings: 다국어 값들(빈값 제거)
        //    examples: example 섹션에서 동일 key의 en/ko만 취해 Example(en:, ko:)로 생성
        var exprSpecs: [BulkParsed.ExprSpec] = []

        let expressions = root.expressions ?? [:]
        let examplesMap = root.example ?? [:]

        for (key, meaningsDict) in expressions {
            // meanings: 값만 모아서 비어있는 것 제거
            let meanings = meaningsDict.values
                .map { $0.trimmed }
                .filter { !$0.isEmpty }

            // examples: "example" 블록에서 같은 키의 en/ko 사용 (없으면 생략)
            var examples: [BulkParsed.ExprExample] = []
            if let ex = examplesMap[key] {
                let en = ex["en"]?.trimmed.trimPeriods()
                let ko = ex["ko"]?.trimmed.trimPeriods()
                if en != nil || ko != nil {
                    examples.append(.init(en: en ?? "", ko: ko))
                }
            }

            exprSpecs.append(.init(text: key, meanings: meanings, examples: examples))
        }

        // 3) words = expressions의 (text, meanings) 축약
        let words = exprSpecs.map { BulkParsed.WordSpec(text: $0.text, meanings: $0.meanings) }

        // 4) 반환
        return BulkParsed(
            title: nil,
            level: level,
            unit: unit,
            topic: topic,
            grammar: grammar,
            words: words,
            expressions: exprSpecs
        )
    }


    private static func parseOldFormats(_ raw: String) throws -> BulkParsed {
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
    func nilIfBlank() -> String? { trimmed.isEmpty ? nil : self.trimmed }
    func trimPeriods() -> String {
        var s = self.trimmed
        while s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
