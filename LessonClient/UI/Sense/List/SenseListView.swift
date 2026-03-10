//
//  SenseListView.swift
//  LessonClient
//
//  Created by ym on 3/9/26.
//

import SwiftUI

struct SenseListView: View {
    @StateObject private var vm = SenseListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack {
                    NavigationLink {
                        SenseCreateView()
                    } label: {
                        Text("Create Sense")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("누락된 Sense출력") {
                        Task { await vm.loadMissingLemmas() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLoading || vm.isLoadingMissingLemmas || vm.isAddingMissingSenses)

                    Button("누락된 Sense추가") {
                        Task { await vm.addMissingSenses() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLoading || vm.isLoadingMissingLemmas || vm.isAddingMissingSenses)

                    Spacer()

                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLoading || vm.isLoadingMissingLemmas || vm.isAddingMissingSenses)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                HStack(spacing: 8) {
                    TextField("sense 검색", text: $vm.q)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await vm.refresh() }
                        }

                    Button("Search") {
                        Task { await vm.refresh() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                if vm.isLoadingMissingLemmas || vm.isAddingMissingSenses {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(vm.progressMessage ?? "누락된 sense 처리 중...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if let progressMessage = vm.progressMessage, !progressMessage.isEmpty {
                    HStack {
                        Text(progressMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                if !vm.missingLemmas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("누락된 Sense 단어")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(vm.missingLemmas.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                List {
                    ForEach(vm.items) { row in
                        NavigationLink {
                            WordDetailView(wordId: row.wordId)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(row.lemma)
                                        .font(.headline)
                                    Spacer()
                                    Text(row.sense.senseCode)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let pos = row.sense.pos, !pos.isEmpty {
                                        Text(pos)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let cefr = row.sense.cefr, !cefr.isEmpty {
                                        Text(cefr)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(row.sense.explain)
                                    .font(.body)

                                if !row.sense.translations.isEmpty {
                                    Text(row.sense.translations.map { "\($0.lang): \($0.text)" }.joined(separator: " • "))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Text("wordId: \(row.wordId) • kind: \(row.kind) • examples: \(row.sense.examples.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .task {
                            await vm.loadMoreIfNeeded(current: row)
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
            .navigationTitle("Senses")
            .task {
                if vm.items.isEmpty {
                    await vm.refresh()
                }
            }
        }
    }
}
