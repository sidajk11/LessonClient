//
//  ExamplesSearchScreen..swift
//  LessonClient
//
//  Created by 정영민 on 8/28/25.
//

import SwiftUI

struct ExamplesSearchScreen: View {
    @State private var q = ""
    @State private var levelText = ""      // ← 레벨 텍스트 입력
    @State private var items: [Example] = []
    @State private var error: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("예문 검색", text: $q)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await search() } }

                TextField("레벨 (빈칸=전체)", text: $levelText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    // 숫자만 허용 (원하면 제거 가능)
                    .onChange(of: levelText) { newValue in
                        levelText = newValue.filter { $0.isNumber }
                    }

                Button("검색") { Task { await search() } }
            }
            .padding(.horizontal)

            List(items) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.sentence)
                    let translations = row.translationsText()
                    Text(translations).foregroundStyle(.secondary)
                    Text("단어: \(row.expressionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("예문")
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func search() async {
        do {
            let trimmed = levelText.trimmingCharacters(in: .whitespacesAndNewlines)
            let levelParam: Int? = trimmed.isEmpty ? nil : Int(trimmed)

            // (선택) 숫자 아님을 오류로 처리하고 싶다면:
            if !trimmed.isEmpty && levelParam == nil {
                self.error = "레벨은 숫자로 입력해 주세요."
                return
            }

            items = try await APIClient.shared.searchExamples(
                q: q,
                level: levelParam,
                limit: 30
            )
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

