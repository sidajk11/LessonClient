//
//  ExamplesSearchView.swift
//  LessonClient
//
//  Created by 정영민 on 8/28/25.
//  MVVM refactor on 10/13/25
//

import SwiftUI

struct ExamplesSearchView: View {
    @StateObject private var vm = ExamplesSearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // 검색 바
                HStack(spacing: 8) {
                    TextField("예문 검색", text: $vm.q)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await vm.search() } }

                    TextField("레벨 (선택)", text: $vm.levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                        .onChange(of: vm.levelText) { _, newValue in
                            vm.levelText = newValue.filter(\.isNumber)
                        }
                        .onSubmit { Task { await vm.search() } }

                    TextField("Unit (선택)", text: $vm.unitText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 110)
                        .onChange(of: vm.unitText) { _, newValue in
                            vm.unitText = newValue.filter(\.isNumber)
                        }
                        .onSubmit { Task { await vm.search() } }

                    Button("검색") { Task { await vm.search() } }

                    Button("start_end_index검사") {
                        Task { await vm.checkStartEndIndices() }
                    }
                    .disabled(
                        vm.isLoading ||
                        vm.isRecreatingAllTokens ||
                        vm.isDeletingTokens ||
                        vm.isAddingSenses ||
                        vm.isCheckingStartEndIndices ||
                        vm.isRepairingStartEndIndices ||
                        vm.displayItems.isEmpty
                    )

                    Button("start_end_index복구") {
                        Task { await vm.repairStartEndIndices() }
                    }
                    .disabled(
                        vm.isLoading ||
                        vm.isRecreatingAllTokens ||
                        vm.isDeletingTokens ||
                        vm.isAddingSenses ||
                        vm.isCheckingStartEndIndices ||
                        vm.isRepairingStartEndIndices ||
                        vm.displayItems.isEmpty
                    )

                    Button("전체 생성") {
                        Task { await vm.recreateAllTokens() }
                    }
                    .disabled(vm.isLoading || vm.isRecreatingAllTokens || vm.isDeletingTokens || vm.isAddingSenses || vm.isCheckingStartEndIndices || vm.isRepairingStartEndIndices || vm.displayItems.isEmpty)

                    Button("토큰 삭제") {
                        Task { await vm.deleteTokensForExamplesWithUnresolvableVocabulary() }
                    }
                    .disabled(vm.isLoading || vm.isRecreatingAllTokens || vm.isDeletingTokens || vm.isAddingSenses || vm.isCheckingStartEndIndices || vm.isRepairingStartEndIndices || !vm.hasDeletableUnresolvableItems)

                    Button("sense 추가") {
                        Task { await vm.addSensesForAllExamples() }
                    }
                    .disabled(vm.isLoading || vm.isRecreatingAllTokens || vm.isDeletingTokens || vm.isAddingSenses || vm.isCheckingStartEndIndices || vm.isRepairingStartEndIndices || vm.displayItems.isEmpty)
                }
                .padding(.horizontal)

                HStack {
                    Toggle("미학습단어 포함만", isOn: $vm.showOnlyUnresolvableVocabulary)
                        .toggleStyle(.checkbox)
                    Spacer()
                }
                .padding(.horizontal)

                if vm.isLoading && vm.items.isEmpty {
                    ProgressView().padding(.top, 8)
                }

                if vm.isRecreatingAllTokens {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(vm.bulkProgressText ?? "전체 생성 중...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if let message = vm.bulkProgressText, !message.isEmpty {
                    HStack {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                if vm.isDeletingTokens {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(vm.deleteProgressText ?? "토큰 삭제 중...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if let message = vm.deleteProgressText, !message.isEmpty {
                    HStack {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                if vm.isAddingSenses {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(vm.senseProgressText ?? "sense 추가 중...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if let message = vm.senseProgressText, !message.isEmpty {
                    HStack {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                if vm.isCheckingStartEndIndices || vm.isRepairingStartEndIndices {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(vm.startEndIndexProgressText ?? "start_end_index 처리 중...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if let message = vm.startEndIndexProgressText, !message.isEmpty {
                    HStack {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // 결과 리스트
                List {
                    ForEach(vm.displayItems) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(vm.unitBadgeText(for: row))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    ExampleSentenceLinksRow(example: row)
                                }

                                Text(row.primaryTranslations.toString())

                                Text("단어: \(row.wordText ?? (row.vocabularyId.map { "#\($0)" } ?? "-"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let sentenceStatus = vm.sentenceStatus(for: row) {
                                    Text(sentenceStatus.text)
                                        .font(.caption)
                                        .foregroundStyle(sentenceStatus.isWarning ? .red : .secondary)
                                }

                                if vm.needsStartEndIndexRepair(for: row) {
                                    Text("start_end_index재생성 필요")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }

                                let sortedTokens = row.primaryTokens.sorted(by: { $0.tokenIndex < $1.tokenIndex })
                                let checkTargets = sortedTokens.filter { token in
                                    !punctuationSet.contains(token.surface)
                                }
                                let isTokenReady = !checkTargets.isEmpty && checkTargets.allSatisfy { token in
                                    token.senseId != nil || token.phraseId != nil
                                }

                                if isTokenReady {
                                    Text("tokens: \(sortedTokens.map(\.surface).joinTokens())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("tokens 수정 필요")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }

                                let senseTokens = checkTargets.map { token -> String in
                                    guard let senseId = token.senseId else {
                                        return "\(token.surface):-"
                                    }
                                    let senseCode = vm.senseCodeBySenseId[senseId] ?? "#\(senseId)"
                                    let cefr = vm.senseCefrBySenseId[senseId] ?? "-"
                                    return "\(senseCode)(\(cefr))"
                                }
                                if !senseTokens.isEmpty {
                                    Text("senses: \(senseTokens.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)

                        }
                        .padding(.vertical, 2)
                    }

                    if vm.isLoading && !vm.items.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("예문")
            .alert("오류", isPresented: .constant(vm.error != nil)) {
                Button("확인") { vm.error = nil }
            } message: { Text(vm.error ?? "") }
        }
    }
}

private struct ExampleSentenceLinksRow: View {
    let example: Example

    var body: some View {
        let sentences = example.orderedExampleSentences

        if sentences.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sentences) { sentence in
                        NavigationLink {
                            ExampleDetailView(exampleId: example.id, exampleSentenceId: sentence.id, lesson: nil, word: nil)
                        } label: {
                            Text(sentence.text)
                                .font(.body)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            NavigationLink {
                ExampleDetailView(exampleId: example.id, exampleSentenceId: sentences.first?.id, lesson: nil, word: nil)
            } label: {
                Text(sentences.first?.text ?? example.sentence)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
    }
}
