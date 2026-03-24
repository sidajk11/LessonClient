//
//  SentenceTokenListView.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import SwiftUI

struct SentenceTokenListView: View {
    @StateObject private var vm = SentenceTokenListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("exampleId", text: $vm.exampleIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("phraseId", text: $vm.phraseIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("wordId", text: $vm.wordIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("formId", text: $vm.formIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("senseId", text: $vm.senseIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    Button("Search") {
                        Task { await vm.refresh() }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                List {
                    if vm.tokens.isEmpty && !vm.isLoading && vm.errorMessage == nil {
                        Text("등록된 sentence token이 없습니다.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.tokens) { token in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("#\(token.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("exampleId: \(token.exampleId)")
                                Text("tokenIndex: \(token.tokenIndex)")
                            }

                            Text(token.surface)
                                .font(.headline)

                            HStack {
                                Text("phraseId: \(token.phraseId.map(String.init) ?? "-")")
                                Text("wordId: \(token.wordId.map(String.init) ?? "-")")
                                Text("formId: \(token.formId.map(String.init) ?? "-")")
                                Text("senseId: \(token.senseId.map(String.init) ?? "-")")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            HStack {
                                Text("pos: \(token.pos ?? "-")")
                                Text("range: \(token.startIndex.map(String.init) ?? "-") ~ \(token.endIndex.map(String.init) ?? "-")")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let vocabulary = token.vocabulary {
                                // 서버가 찾아준 vocabulary 연결을 바로 보여줍니다.
                                Text("vocabulary: #\(vocabulary.id) \(vocabulary.text)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.delete(token) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .task {
                            await vm.loadMoreIfNeeded(current: token)
                        }
                    }

                    if vm.isLoading && !vm.tokens.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await vm.refresh()
                }
            }
            .navigationTitle("Sentence Tokens")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if vm.tokens.isEmpty {
                    await vm.refresh()
                }
            }
        }
    }
}
