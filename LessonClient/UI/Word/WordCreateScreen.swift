//
//  WordCreateScreen.swift
//  LessonClient
//
//  Created by ymj on 9/9/25.
//

import SwiftUI

struct WordCreateScreen: View {
    var onCreated: ((Word) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var meaningsInput = ""
    @State private var error: String?

    var body: some View {
        Form {
            TextField("표현", text: $text)
            TextField("뜻(쉼표 / 슬래시)", text: $meaningsInput)
            Button("생성") {
                Task {
                    do {
                        let meanings = parseMeanings(meaningsInput)
                        let w = try await WordDataSource.shared.createWord(text: text, meanings: meanings)
                        onCreated?(w)
                        dismiss()
                    } catch { self.error = (error as NSError).localizedDescription }
                }
            }
            if let e = error { Text(e).foregroundStyle(.red) }
        }
        .navigationTitle("새 표현")
    }

    private func parseMeanings(_ text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "/" || $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct BulkExpressionImportScreen: View {
    var onImported: (([Expression]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var isImporting = false
    @State private var error: String?

    private let example = "and^그리고\nmy^나의 / 내\nbag ^ 가방\nphone ^ 전화 / 휴대폰"

    var body: some View {
        Form {
            Section("포맷과 예시") {
                Text("각 줄에 `영어^뜻1 / 뜻2` 형태로 입력하세요. 공백은 자동으로 정리됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(example)
                    .font(.footnote)
                    .monospaced()
                    .padding(.vertical, 4)
            }

            Section("붙여넣기") {
                TextEditor(text: $input)
                    .frame(minHeight: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    )
            }

            if let preview = previewPairs(), !preview.isEmpty {
                Section("미리보기 (\(preview.count)개)") {
                    ForEach(Array(preview.enumerated()), id: \.0) { _, p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.0)
                            Text(p.1.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button {
                Task { await importAll() }
            } label: {
                if isImporting { ProgressView() } else { Text("일괄 추가") }
            }
            .disabled(isImporting || previewPairs()?.isEmpty != false)

            if let e = error { Text(e).foregroundStyle(.red) }
        }
        .navigationTitle("여러 개 추가")
    }

    private func previewPairs() -> [(String, [String])]? {
        let lines = input
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        var result: [(String, [String])] = []
        for line in lines {
            // split with '^' (first occurrence only)
            guard let caretIndex = line.firstIndex(of: "^") else { continue }
            let left = String(line[..<caretIndex]).trimmingCharacters(in: .whitespaces)
            let right = String(line[line.index(after: caretIndex)...]).trimmingCharacters(in: .whitespaces)
            guard !left.isEmpty, !right.isEmpty else { continue }

            // meanings can be separated by '/', ',', or newlines
            let parts = right
                .split(whereSeparator: { $0 == "/" || $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if !parts.isEmpty { result.append((left, parts)) }
        }
        return result
    }

    private func importAll() async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        let pairs = previewPairs() ?? []
        var created: [Expression] = []
        for (text, meanings) in pairs {
            do {
                let w = try await WordDataSource.shared.createWord(text: text, meanings: meanings)
                created.append(w)
            } catch {
                // 개별 실패는 스킵하고 마지막에 에러 표시
                self.error = (error as NSError).localizedDescription
            }
        }
        if !created.isEmpty { onImported?(created) }
        dismiss()
    }
}
