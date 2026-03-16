//
//  SenseListView.swift
//  LessonClient
//
//  Created by ym on 3/9/26.
//

import SwiftUI

struct SenseListView: View {
    @StateObject private var vm = SenseListViewModel()
    @State private var isPresentingAutoGenerateSheet = false
    @State private var autoGenerateInput = ""

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
                    .disabled(vm.isBusy)

                    Button("누락된 Sense추가") {
                        Task { await vm.addMissingSenses() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isBusy)

                    Button("Sense자동 생성(단어)") {
                        isPresentingAutoGenerateSheet = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isBusy)

                    Spacer()

                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isBusy)
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

                if vm.isLoadingMissingLemmas || vm.isAddingMissingSenses || vm.isAutoGeneratingSenses {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(vm.progressMessage ?? "sense 처리 중...")
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
            .sheet(isPresented: $isPresentingAutoGenerateSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("쉼표 또는 줄바꿈으로 단어/구문을 입력하세요. 먼저 lemma로 정규화한 뒤 각 lemma의 sense를 생성합니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $autoGenerateInput)
                            .frame(minHeight: 180)
                            .padding(8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.25))
                            }

                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Sense 자동 생성")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("취소") {
                                isPresentingAutoGenerateSheet = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("생성") {
                                let input = autoGenerateInput
                                autoGenerateInput = ""
                                isPresentingAutoGenerateSheet = false
                                Task { await vm.autoGenerateSenses(from: input) }
                            }
                            .disabled(autoGenerateInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isBusy)
                        }
                    }
                }
            }
        }
    }
}
