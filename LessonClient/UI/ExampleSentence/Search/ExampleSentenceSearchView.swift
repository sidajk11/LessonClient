//
//  ExampleSentenceSearchView.swift
//  LessonClient
//
//  Created by Codex on 3/30/26.
//

import SwiftUI

struct ExampleSentenceSearchView: View {
    @StateObject private var vm = ExampleSentenceSearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("예문 문장 검색", text: $vm.q)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await vm.search() } }

                    TextField("레벨 (선택)", text: $vm.levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                        .onChange(of: vm.levelText) { _, newValue in
                            vm.sanitizeLevel(newValue)
                        }
                        .onSubmit { Task { await vm.search() } }

                    TextField("Unit (선택)", text: $vm.unitText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                        .onChange(of: vm.unitText) { _, newValue in
                            vm.sanitizeUnit(newValue)
                        }
                        .onSubmit { Task { await vm.search() } }

                    Button("검색") {
                        Task { await vm.search() }
                    }
                }
                .padding(.horizontal)

                HStack {
                    Toggle("여러 문장 예문만", isOn: $vm.showOnlyMultiSentence)
                        .toggleStyle(.checkbox)
                    Spacer()
                }
                .padding(.horizontal)

                if vm.isLoading && vm.items.isEmpty {
                    ProgressView().padding(.top, 8)
                }

                List(vm.items) { row in
                    ExampleSentenceSearchRow(item: row, vm: vm)
                        .padding(.vertical, 2)
                }
            }
            .navigationTitle("예문 문장")
            .alert("오류", isPresented: .constant(vm.error != nil)) {
                Button("확인") { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
        }
    }
}

private struct ExampleSentenceSearchRow: View {
    let item: ExampleSentenceSearchViewModel.Item
    @ObservedObject var vm: ExampleSentenceSearchViewModel

    var body: some View {
        let sortedTokens = item.sentence.tokens.sorted(by: { $0.tokenIndex < $1.tokenIndex })
        let visibleTokens = sortedTokens.filter { !punctuationSet.contains($0.surface) }
        let isTokenReady = !visibleTokens.isEmpty && visibleTokens.allSatisfy { token in
            token.senseId != nil || token.phraseId != nil
        }
        let senseTokens = visibleTokens.map { token -> String in
            guard let senseId = token.senseId else {
                return "\(token.surface):-"
            }
            let senseCode = vm.senseCodeBySenseId[senseId] ?? "#\(senseId)"
            let cefr = vm.senseCefrBySenseId[senseId] ?? "-"
            return "\(senseCode)(\(cefr))"
        }

        HStack(alignment: .top, spacing: 12) {
            NavigationLink {
                // sentence 단위 검색이므로 해당 sentence 상세로 바로 이동합니다.
                ExampleSentenceDetailView(exampleSentence: item.sentence, lesson: nil, word: nil)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(vm.unitBadgeText(for: item.example))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text(item.sentence.text)
                            .font(.body)
                            .lineLimit(2)
                    }

                    if !item.sentence.translations.isEmpty {
                        Text(item.sentence.translations.toString())
                    }

                    Text("example_id: \(item.example.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("단어: \(item.example.wordText ?? (item.example.vocabularyId.map { "#\($0)" } ?? "-"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("sentence_id: \(item.sentence.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isTokenReady {
                        Text("tokens: \(sortedTokens.map(\.surface).joinTokens())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !sortedTokens.isEmpty {
                        Text("tokens 수정 필요")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !senseTokens.isEmpty {
                        Text("senses: \(senseTokens.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("연습문제: \(item.sentence.exercises.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 8) {
                Button(role: .destructive) {
                    Task { await vm.deleteExercises(for: item) }
                } label: {
                    if vm.isDeletingExercises(for: item.sentence.id) {
                        ProgressView()
                    } else {
                        Text("연습문제 삭제")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isDeletingExercises(for: item.sentence.id) || vm.isGeneratingExercises(for: item.sentence.id))

                Button {
                    Task { await vm.autoGenerateExercises(for: item) }
                } label: {
                    if vm.isGeneratingExercises(for: item.sentence.id) {
                        ProgressView()
                    } else {
                        Text("연습문제 자동생성")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isDeletingExercises(for: item.sentence.id) || vm.isGeneratingExercises(for: item.sentence.id))
            }
        }
    }
}
