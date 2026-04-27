//
//  UnitLevelListView.swift
//  LessonClient
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct UnitLevelListView: View {
    @StateObject private var vm = UnitLevelListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                filterBar
                createBar

                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                List {
                    if vm.items.isEmpty && !vm.isLoading && vm.errorMessage == nil {
                        ContentUnavailableView(
                            "등록된 유닛 레벨이 없습니다.",
                            systemImage: "list.number"
                        )
                    }

                    ForEach(vm.items) { item in
                        UnitLevelRowView(
                            item: item,
                            onLevelChange: { vm.updateLevelText(for: item, value: $0) },
                            onStartUnitChange: { vm.updateStartUnitText(for: item, value: $0) },
                            onSave: { Task { await vm.save(item) } },
                            onReset: { vm.reset(item) },
                            onDelete: { Task { await vm.delete(item) } }
                        )
                        .task {
                            await vm.loadMoreIfNeeded(current: item)
                        }
                    }

                    if vm.isLoading && !vm.items.isEmpty {
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
            .navigationTitle("유닛 레벨")
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
                if vm.items.isEmpty {
                    await vm.refresh()
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            TextField("레벨", text: $vm.levelFilterText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
                .onChange(of: vm.levelFilterText) { _, newValue in
                    vm.sanitizeLevelFilter(newValue)
                }
                .onSubmit { Task { await vm.refresh() } }

            TextField("시작 유닛", text: $vm.startUnitFilterText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
                .onChange(of: vm.startUnitFilterText) { _, newValue in
                    vm.sanitizeStartUnitFilter(newValue)
                }
                .onSubmit { Task { await vm.refresh() } }

            Button("검색") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var createBar: some View {
        HStack(spacing: 8) {
            TextField("새 레벨", text: $vm.newLevelText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
                .onChange(of: vm.newLevelText) { _, newValue in
                    vm.sanitizeNewLevel(newValue)
                }
                .onSubmit { Task { await vm.create() } }

            TextField("새 시작 유닛", text: $vm.newStartUnitText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 140)
                .onChange(of: vm.newStartUnitText) { _, newValue in
                    vm.sanitizeNewStartUnit(newValue)
                }
                .onSubmit { Task { await vm.create() } }

            Button {
                Task { await vm.create() }
            } label: {
                if vm.isCreating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("추가", systemImage: "plus")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canCreate)

            Spacer()
        }
        .padding(.horizontal)
    }
}

private struct UnitLevelRowView: View {
    let item: UnitLevelListViewModel.EditableUnitLevel
    let onLevelChange: (String) -> Void
    let onStartUnitChange: (String) -> Void
    let onSave: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("#\(item.id)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Level", text: levelBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Start Unit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Start Unit", text: startUnitBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
            }

            Spacer()

            if item.isSaving {
                ProgressView()
                    .controlSize(.small)
            }

            Button("저장", action: onSave)
                .buttonStyle(.borderedProminent)
                .disabled(!item.hasChanges || item.isSaving)

            Button("되돌리기", action: onReset)
                .disabled(!item.hasChanges || item.isSaving)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .disabled(item.isSaving)
        }
        .padding(.vertical, 6)
    }

    private var levelBinding: Binding<String> {
        Binding(
            get: { item.levelText },
            set: onLevelChange
        )
    }

    private var startUnitBinding: Binding<String> {
        Binding(
            get: { item.startUnitText },
            set: onStartUnitChange
        )
    }
}
