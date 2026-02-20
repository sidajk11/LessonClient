//
//  WordList.swift
//  LessonClient
//
//  Created by ym on 2/12/26.
//

import SwiftUI

struct WordListView: View {
    @StateObject private var vm = WordListViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Top bar: Create Sense 이동
                HStack {
                    NavigationLink {
                        SenseCreateView()
                    } label: {
                        Text("Create Sense")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Search
                HStack(spacing: 8) {
                    TextField("Search (q)", text: $vm.q)
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
                
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                
                List {
                    ForEach(vm.words) { w in
                        NavigationLink {
                            WordDetailView(wordId: w.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(w.lemma)
                                        .font(.headline)
                                    Spacer()
                                    if let p = w.senses.first(where: { $0.isPrimary })?.pos, !p.isEmpty {
                                        Text(p)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Text("kind: \(w.kind) • normalized: \(w.normalized)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                
                                if !w.senses.isEmpty {
                                    Text("senses: \(w.senses.count)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if let count = w.senses.first?.translations.count, count > 2 {
                                    Text("translations done")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .foregroundStyle(Color.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .task {
                            await vm.loadMoreIfNeeded(current: w)
                        }
                    }
                    
                    if vm.isLoading && !vm.words.isEmpty {
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
            .navigationTitle("Words")
            .task {
                if vm.words.isEmpty {
                    await vm.refresh()
                }
            }
        }
    }
}
