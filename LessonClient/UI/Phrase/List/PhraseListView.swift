//
//  PhraseListView.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import SwiftUI

struct PhraseListView: View {
    @StateObject private var vm = PhraseListViewModel()
    @State private var showingCreate = false
    @State private var deletingPhrase: PhraseRead?

    var body: some View {
        NavigationStack {
            List {
                Section("검색") {
                    HStack {
                        TextField("phrase 검색", text: $vm.q)
                            .onSubmit { Task { await vm.load() } }
                        Button("검색") { Task { await vm.load() } }
                    }
                }

                if let error = vm.errorMessage {
                    Section("오류") {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section("Phrases (\(vm.items.count))") {
                    if vm.isLoading && vm.items.isEmpty {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if vm.items.isEmpty {
                        Text("등록된 Phrase가 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.items) { item in
                            HStack(spacing: 12) {
                                NavigationLink {
                                    PhraseDetailView(phraseId: item.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(item.text).bold()
                                            Spacer()
                                            Text("#\(item.id)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(item.translations.map { "\($0.lang): \($0.text)" }.joined(separator: " | "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    deletingPhrase = item
                                } label: {
                                    if vm.deletingIds.contains(item.id) {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                }
                                .buttonStyle(.borderless)
                                .disabled(vm.deletingIds.contains(item.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Phrases")
            .task { await vm.load() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Phrase 추가")
                }
            }
            .sheet(isPresented: $showingCreate, onDismiss: {
                Task { await vm.load() }
            }) {
                NavigationStack {
                    PhraseCreateView {
                        Task { await vm.load() }
                    }
                    .padding()
                    .frame(minWidth: 520, minHeight: 460)
                }
            }
            .confirmationDialog(
                "Phrase를 삭제할까요?",
                isPresented: Binding(
                    get: { deletingPhrase != nil },
                    set: { isPresented in
                        if !isPresented {
                            deletingPhrase = nil
                        }
                    }
                ),
                presenting: deletingPhrase
            ) { phrase in
                Button("삭제", role: .destructive) {
                    Task {
                        await vm.deletePhrase(id: phrase.id)
                        deletingPhrase = nil
                    }
                }
                Button("취소", role: .cancel) {
                    deletingPhrase = nil
                }
            } message: { phrase in
                Text("\"\(phrase.text)\" 구문을 삭제합니다.")
            }
        }
    }
}
