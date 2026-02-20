//
//  FormListView.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import SwiftUI

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
                            showCreate = false
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

            if let msg = vm.errorMessage {
                Text(msg)
                    .foregroundStyle(.red)
                    .padding(8)
            }

            Table(vm.items, selection: $vm.selection) {
                TableColumn("Form") { item in
                    Text(item.form)
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
