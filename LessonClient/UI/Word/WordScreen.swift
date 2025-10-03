//
//  WordDetail.swift
//  LessonClient
//
//  Created by ymj on 9/5/25.
//

import SwiftUI

struct WordsScreen: View {
    @State private var items: [Expression] = []
    @State private var searchText = ""
    @State private var levelText = ""      // ← 레벨 입력
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack {
                // 검색 UI
                HStack(spacing: 8) {
                    TextField("표현 검색", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await search() } }

                    TextField("레벨 (빈칸=전체)", text: $levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .onSubmit { Task { await search() } }

                    Button("검색") { Task { await search() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                List(items) { e in
                    NavigationLink {
                        WordDetailScreen(expressionId: e.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.text)
                            if !e.translations.isEmpty {
                                Text(e.translationsText())
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .task { await load() }

                NavigationLink(
                    "+ 새 표현",
                    destination: WordCreateScreen(onCreated: { w in
                        items.insert(w, at: 0)
                    })
                )
                .padding(.vertical)

                NavigationLink(
                    "+ 여러 개 추가",
                    destination: BulkExpressionImportScreen(onImported: { list in
                        items.insert(contentsOf: list, at: 0)
                    })
                )
                .padding(.horizontal)
            }
            .navigationTitle("표현")
        }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func load() async {
        do {
            items = try await ExpressionDataSource.shared.expressions()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func search() async {
        do {
            let trimmed = levelText.trimmingCharacters(in: .whitespacesAndNewlines)
            let levelParam: Int? = trimmed.isEmpty ? nil : Int(trimmed)

            if !trimmed.isEmpty && levelParam == nil {
                self.error = "레벨은 숫자로 입력해 주세요."
                return
            }

            items = try await ExpressionDataSource.shared.searchExpressions(
                q: searchText,
                level: levelParam,      // ← 레벨 전달
                limit: 50
            )
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}



