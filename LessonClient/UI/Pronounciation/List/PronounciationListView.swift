//
//  PronounciationListView.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import SwiftUI

struct PronounciationListView: View {
    @StateObject private var vm = PronounciationListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("wordId", text: $vm.wordIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    TextField("senseId", text: $vm.senseIdText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)

                    Picker("Dialect", selection: $vm.dialectFilter) {
                        ForEach(PronounciationListViewModel.DialectFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .frame(maxWidth: 140)

                    Button("Search") {
                        Task { await vm.refresh() }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    NavigationLink {
                        PronounciationView()
                    } label: {
                        Label("Bulk Create", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
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
                    if vm.pronunciations.isEmpty && !vm.isLoading && vm.errorMessage == nil {
                        Text("등록된 발음이 없습니다.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.pronunciations) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("#\(p.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("wordId: \(p.wordId)")
                                Text("senseId: \(p.senseId.map(String.init) ?? "-")")
                            }

                            Text(p.ipa)
                                .font(.system(.body, design: .monospaced))

                            HStack {
                                Text("dialect: \(p.dialect.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("primary: \(p.isPrimary ? "Y" : "N")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let ttsProvider = p.ttsProvider, !ttsProvider.isEmpty {
                                    Text(ttsProvider)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.delete(p) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .task {
                            await vm.loadMoreIfNeeded(current: p)
                        }
                    }

                    if vm.isLoading && !vm.pronunciations.isEmpty {
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
            .navigationTitle("Pronunciations")
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
                if vm.pronunciations.isEmpty {
                    await vm.refresh()
                }
            }
        }
    }
}

