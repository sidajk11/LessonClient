//
//  ExamplesSearchView.swift
//  LessonClient
//
//  Created by 정영민 on 8/28/25.
//  MVVM refactor on 10/13/25
//

import SwiftUI

struct ExamplesSearchView: View {
    @StateObject private var vm = ExamplesSearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // 검색 바
                HStack(spacing: 8) {
                    TextField("예문 검색", text: $vm.q)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await vm.search() } }

                    TextField("레벨 (선택)", text: $vm.levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                        .onChange(of: vm.levelText) { _, newValue in
                            vm.sanitizeLevelInput(newValue)
                        }
                        .onSubmit { Task { await vm.search() } }

                    TextField("Unit (선택)", text: $vm.unitText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 110)
                        .onChange(of: vm.unitText) { _, newValue in
                            vm.sanitizeUnitInput(newValue)
                        }
                        .onSubmit { Task { await vm.search() } }

                    Button("검색") { Task { await vm.search() } }
                }
                .padding(.horizontal)

                if vm.isLoading && vm.items.isEmpty {
                    ProgressView().padding(.top, 8)
                }

                // 결과 리스트
                List(vm.items) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        NavigationLink {
                            ExampleDetailView(exampleId: row.id, lesson: nil, word: nil)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.sentence)
                                    .font(.body)

                                Text(row.translations.toString())

                                Text("단어: \(row.wordText ?? (row.vocabularyId.map { "#\($0)" } ?? "-"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                let sortedTokens = row.tokens.sorted(by: { $0.tokenIndex < $1.tokenIndex })
                                let checkTargets = sortedTokens.filter { token in
                                    !punctuationSet.contains(token.surface)
                                }
                                let isTokenReady = !checkTargets.isEmpty && checkTargets.allSatisfy { token in
                                    token.senseId != nil || token.phraseId != nil
                                }

                                if isTokenReady {
                                    Text("tokens: \(sortedTokens.map(\.surface).joinTokens())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("tokens 수정 필요")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("예문")
            .alert("오류", isPresented: .constant(vm.error != nil)) {
                Button("확인") { vm.error = nil }
            } message: { Text(vm.error ?? "") }
        }
    }
}
