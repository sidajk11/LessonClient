//
//  SentenceTokenDetailView.swift
//  LessonClient
//
//  Created by Codex on 3/4/26.
//

import SwiftUI

struct SentenceTokenDetailView: View {
    @StateObject private var vm: SentenceTokenDetailViewModel

    init(tokenId: Int) {
        _vm = StateObject(wrappedValue: SentenceTokenDetailViewModel(tokenId: tokenId))
    }

    var body: some View {
        Form {
            if let token = vm.token {
                Section("기본") {
                    infoRow("tokenId", "\(token.id)")
                    TextField("exampleId", text: $vm.exampleIdText)
                        .textFieldStyle(.roundedBorder)
                    TextField("tokenIndex", text: $vm.tokenIndexText)
                        .textFieldStyle(.roundedBorder)
                    TextField("surface", text: $vm.surfaceText)
                        .textFieldStyle(.roundedBorder)
                }

                Section("연결") {
                    TextField("phraseId (optional)", text: $vm.phraseIdText)
                        .textFieldStyle(.roundedBorder)
                    TextField("wordId (optional)", text: $vm.wordIdText)
                        .textFieldStyle(.roundedBorder)
                    TextField("formId (optional)", text: $vm.formIdText)
                        .textFieldStyle(.roundedBorder)
                    TextField("senseId (optional)", text: $vm.senseIdText)
                        .textFieldStyle(.roundedBorder)
                }

                Section("추가 정보") {
                    TextField("pos (optional)", text: $vm.posText)
                        .textFieldStyle(.roundedBorder)
                    TextField("startIndex (optional)", text: $vm.startIndexText)
                        .textFieldStyle(.roundedBorder)
                    TextField("endIndex (optional)", text: $vm.endIndexText)
                        .textFieldStyle(.roundedBorder)
                    infoRow(
                        "createdAt",
                        token.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "-"
                    )
                    infoRow(
                        "vocabulary",
                        token.vocabulary.map { "#\($0.id) \($0.text)" } ?? "-"
                    )
                }

                Section("번역") {
                    if token.translations.isEmpty {
                        Text("번역이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(token.translations.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.lang.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(row.text)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        Task { await vm.save() }
                    } label: {
                        if vm.isSaving {
                            ProgressView()
                        } else {
                            Text("저장")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isSaving || vm.isLoading)
                }
            } else if vm.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("불러오는 중...")
                        Spacer()
                    }
                }
            } else {
                Section {
                    Text("Sentence token 정보를 불러오지 못했습니다.")
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = vm.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let infoMessage = vm.infoMessage {
                Section {
                    Text(infoMessage)
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Token Detail")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading || vm.isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    Task { await vm.save() }
                }
                .disabled(vm.token == nil || vm.isLoading || vm.isSaving)
            }
        }
        .task {
            await vm.load()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
