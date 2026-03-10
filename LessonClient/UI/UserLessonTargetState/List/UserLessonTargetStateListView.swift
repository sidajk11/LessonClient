//
//  UserLessonTargetStateListView.swift
//  LessonClient
//
//  Created by Codex on 2/26/26.
//

import SwiftUI

struct UserVocabularyStateListView: View {
    @StateObject private var vm = UserVocabularyStateListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("userId", text: $vm.userIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("vocabularyId", text: $vm.vocabularyIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)

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
                        Text("등록된 user vocabulary state가 없습니다.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.items) { state in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("#\(state.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("userId: \(state.userId)")
                                Text("vocabularyId: \(state.vocabularyId)")
                            }

                            HStack {
                                Text("attempts: \(state.attempts)")
                                    .font(.subheadline)
                                Text("correct: \(state.correctAttempts)")
                                    .font(.subheadline)
                                Text("wrongStreak: \(state.wrongStreak)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("lastAttemptAt: \(vm.formattedDate(state.lastAttemptAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("lastCorrectAt: \(vm.formattedDate(state.lastCorrectAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("nextReviewAt: \(vm.formattedDate(state.nextReviewAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("updatedAt: \(vm.formattedDate(state.updatedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.delete(state) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .task {
                            await vm.loadMoreIfNeeded(current: state)
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
            .navigationTitle("User Vocabulary States")
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

typealias UserLessonTargetStateListView = UserVocabularyStateListView
