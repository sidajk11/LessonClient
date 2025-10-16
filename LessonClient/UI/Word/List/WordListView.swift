//
//  WordListView.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import SwiftUI

struct WordListView: View {
    @StateObject private var vm = WordListViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                // 검색 UI
                HStack(spacing: 8) {
                    TextField("단어 검색", text: $vm.searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await vm.search() } }

                    TextField("레벨 (빈칸=전체)", text: $vm.levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .onSubmit { Task { await vm.search() } }

                    Button("검색") { Task { await vm.search() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isLoading)
                }
                .padding(.horizontal)

                if vm.isLoading && vm.items.isEmpty {
                    ProgressView().padding()
                }

                List(vm.items) { e in
                    NavigationLink {
                        WordDetailView(wordId: e.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.text)
                            if !e.translation.isEmpty {
                                Text(e.translation.toString())
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .task { await vm.load() }

                NavigationLink(
                    "+ 새 단어",
                    destination: WordCreateView(onCreated: { w in
                        vm.didCreate(w)
                    })
                )
                .padding(.vertical)

                NavigationLink(
                    "+ 여러 개 추가",
                    destination: WordBulkImportScreen(onImported: { list in
                        vm.didImport(list)
                    })
                )
                .padding(.horizontal)
            }
            .navigationTitle("단어")
        }
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}
