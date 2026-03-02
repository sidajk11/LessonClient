//
//  ExerciseAttemptListView.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import SwiftUI

struct ExerciseAttemptListView: View {
    @StateObject private var vm = ExerciseAttemptListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("userId", text: $vm.userIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("exerciseId", text: $vm.exerciseIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    Picker("Result", selection: $vm.correctnessFilter) {
                        ForEach(ExerciseAttemptListViewModel.CorrectnessFilter.allCases) { filter in
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
                    if vm.attempts.isEmpty && !vm.isLoading && vm.errorMessage == nil {
                        Text("등록된 exercise attempt가 없습니다.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.attempts) { attempt in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(attempt.id.uuidString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                Text("userId: \(attempt.userId)")
                                Text("exerciseId: \(attempt.exerciseId)")
                            }

                            HStack {
                                Text(attempt.isCorrect ? "정답" : "오답")
                                    .font(.subheadline)
                                    .foregroundStyle(attempt.isCorrect ? .green : .orange)

                                Text("score: \(attempt.score.map(String.init) ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("duration: \(attempt.durationMs.map(String.init) ?? "-") ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("createdAt: \(vm.formattedCreatedAt(attempt.createdAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.delete(attempt) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .task {
                            await vm.loadMoreIfNeeded(current: attempt)
                        }
                    }

                    if vm.isLoading && !vm.attempts.isEmpty {
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
            .navigationTitle("Exercise Attempts")
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
                if vm.attempts.isEmpty {
                    await vm.refresh()
                }
            }
        }
    }
}
