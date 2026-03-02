//
//  ExerciseQueueListView.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import SwiftUI

struct ExerciseQueueListView: View {
    @StateObject private var vm = ExerciseQueueListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("userId", text: $vm.userIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("batchId", text: $vm.batchIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("exerciseId", text: $vm.exerciseIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    Picker("Consumed", selection: $vm.consumedFilter) {
                        ForEach(ExerciseQueueListViewModel.ConsumedFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .frame(maxWidth: 160)

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
                    if vm.items.isEmpty && !vm.isLoading && vm.errorMessage == nil {
                        Text("등록된 exercise queue가 없습니다.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.items) { queue in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("#\(queue.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("userId: \(queue.userId)")
                                Text("exerciseId: \(queue.exerciseId)")
                            }

                            HStack {
                                Text("batchId: \(queue.batchId)")
                                    .font(.subheadline)
                                Text("position: \(queue.position)")
                                    .font(.subheadline)
                                Text("batchUnit: \(queue.batchUnit.map(String.init) ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("batchCompletedAt: \(vm.formattedDate(queue.batchCompletedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("consumedAt: \(vm.formattedDate(queue.consumedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("createdAt: \(vm.formattedDate(queue.createdAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.delete(queue) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .task {
                            await vm.loadMoreIfNeeded(current: queue)
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
            .navigationTitle("Exercise Queues")
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
}
