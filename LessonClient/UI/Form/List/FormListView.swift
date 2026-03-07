//
//  FormListView.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import SwiftUI

struct FormListView: View {
    @StateObject private var vm: FormListViewModel
    @State private var showCreate = false

    init(wordId: Int? = nil) {
        _vm = StateObject(wrappedValue: FormListViewModel(wordId: wordId))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Word Forms")
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            showCreate = true
                        } label: {
                            Label("Add Forms", systemImage: "plus")
                        }

                        Button {
                            vm.openEditSelected()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .disabled(vm.selection.count != 1)

                        Button(role: .destructive) {
                            Task { await vm.deleteSelected() }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(vm.selection.isEmpty)
                    }
                }
                .navigationDestination(isPresented: $showCreate) {
                    FormCreateView(
                        onFinished: {
                            //showCreate = false
                        }
                    )
                }
                .onAppear {
                    Task { await vm.onAppearRefreshIfNeeded() }
                }
        }
    }

    // 기존 Table UI 그대로 분리
    private var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Form 검색", text: $vm.query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await vm.refresh() }
                    }

                Button("검색") {
                    Task { await vm.refresh() }
                }
                .buttonStyle(.borderedProminent)

                if !vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("초기화") {
                        vm.query = ""
                        Task { await vm.refresh() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if let msg = vm.errorMessage {
                Text(msg)
                    .foregroundStyle(.red)
                    .padding(8)
            }

            Table(vm.items, selection: $vm.selection) {
                TableColumn("Form") { item in
                    HStack(spacing: 8) {
                        Text(item.form)
                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            Task { await vm.delete(item) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .task {
                        await vm.loadMoreIfNeeded(currentItem: item)
                    }
                }

                TableColumn("Type") { item in
                    Text(item.formType ?? "")
                        .foregroundStyle(.secondary)
                }

                TableColumn("Word ID") { item in
                    Text("\(item.wordId)")
                        .foregroundStyle(.secondary)
                }

                TableColumn("ID") { item in
                    Text("\(item.id)")
                        .foregroundStyle(.secondary)
                }
                .width(min: 60, ideal: 80)
            }
        }
    }
}
