//
//  VocabularyListView.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import SwiftUI

struct VocabularyListView: View {
    @StateObject private var vm = VocabularyListViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                // 검색 UI
                HStack(spacing: 8) {
                    TextField("단어 검색", text: $vm.searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await vm.search() } }

                    TextField("레벨 (빈칸=전체)", text: $vm.levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onSubmit { Task { await vm.search() } }

                    TextField("Unit (빈칸=전체)", text: $vm.unitText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onSubmit { Task { await vm.search() } }

                    Button("검색") { Task { await vm.search() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isLoading)
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Toggle("예문 없는 단어만", isOn: $vm.showOnlyWithoutExamples)
                        .toggleStyle(CheckboxToggleStyle())
                        .onChange(of: vm.showOnlyWithoutExamples) { _, _ in
                            Task { await vm.search() }
                        }

                    Spacer()

                    Button("검사") {
                        Task { await vm.checkCurrentItems() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!vm.canCheckLinks)

                    Button("검사결과 적용") {
                        Task { await vm.applyAuditResultsToCurrentItems() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.canApplyAuditResults)

                    Button("예문 만들기") {
                        vm.openSentenceGenerator()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.canGenerateExamples)
                }
                .padding(.horizontal)

                if let progressText = vm.progressText, !progressText.isEmpty {
                    Text(progressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                if vm.isLoading && vm.items.isEmpty {
                    ProgressView().padding()
                }

                List(vm.items) { e in
                    NavigationLink {
                        VocabularyDetailView(wordId: e.id, lesson: nil)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.text)
                            if let unit = vm.unitByVocabularyId[e.id] {
                                Text("U\(unit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !e.translations.isEmpty {
                                Text(e.translations.toString())
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            if let examples = e.examples {
                                Text(examples.isEmpty ? "예문 없음" : "예문 \(examples.count)개")
                                    .font(.caption)
                                    .foregroundStyle(examples.isEmpty ? .orange : .secondary)
                            }

                            if let audit = vm.linkAuditByVocabularyId[e.id] {
                                Text(audit.requiresSenseFix ? "센스수정 필요" : "정상")
                                    .font(.caption)
                                    .foregroundStyle(audit.requiresSenseFix ? .red : .green)

                                Text(auditDetailText(audit))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .task { await vm.load() }

                NavigationLink(
                    "+ 새 단어",
                    destination: VocabularyCreateView(onCreated: { words in
                        vm.didCreate(words)
                    })
                )
                .padding(.vertical)

                NavigationLink(
                    "+ 여러 개 추가",
                    destination: VocabularyBulkImportScreen(onImported: { list in
                        vm.didImport(list)
                    })
                )
                .padding(.horizontal)
            }
            .navigationTitle("단어")
        }
        .sheet(isPresented: $vm.isSentenceGeneratorPresented) {
            sentenceGeneratorSheet
        }
        .alert("오류", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .alert("완료", isPresented: Binding(
            get: { vm.info != nil },
            set: { if !$0 { vm.info = nil } }
        )) {
            Button("확인") { vm.info = nil }
        } message: { Text(vm.info ?? "") }
    }

    private var sentenceGeneratorSheet: some View {
        NavigationStack {
            Form {
                Section("설정") {
                    TextField("CEFR", text: $vm.sentenceCefr)
                }

                Section("대상") {
                    Text("현재 단어 \(vm.items.count)개")
                    Text("각 단어가 속한 레슨의 토픽을 사용해 `makeSentencePrompt`와 OpenAI 호출로 예문을 생성합니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let progressText = vm.progressText, !progressText.isEmpty {
                    Section("진행") {
                        Text(progressText)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("예문 만들기")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        vm.isSentenceGeneratorPresented = false
                    }
                    .disabled(vm.isGeneratingExamples)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("전체 만들기") {
                        Task { await vm.generateExamplesForCurrentItems() }
                    }
                    .disabled(vm.isLoading || vm.isGeneratingExamples)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 260)
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

private func auditDetailText(_ audit: VocabularyLinkAuditResult) -> String {
    let cefrText = audit.cefr ?? "-"
    return "현재 p/f/s \(displayId(audit.currentPhraseId))/\(displayId(audit.currentFormId))/\(displayId(audit.currentSenseId)) | 조회 p/f/s \(displayId(audit.expectedPhraseId))/\(displayId(audit.expectedFormId))/\(displayId(audit.expectedSenseId)) | CEFR \(cefrText)"
}

private func displayId(_ value: Int?) -> String {
    value.map(String.init) ?? "-"
}
