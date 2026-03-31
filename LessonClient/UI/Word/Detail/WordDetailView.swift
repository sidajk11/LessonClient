//
//  WordDetailView.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import SwiftUI
import AppKit


struct WordDetailView: View {
    @StateObject private var vm: WordDetailViewModel

    @State private var showCopyToast = false
    @State private var copyStatus: String = ""

    init(wordId: Int) {
        _vm = StateObject(wrappedValue: WordDetailViewModel(wordId: wordId))
    }

    var body: some View {
        List {
            if let word = vm.word {
                Section("Lemma") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(word.lemma)
                            .font(.title3)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            Button {
                                vm.showAddTranslationsSheet = true
                            } label: {
                                Label("번역추가", systemImage: "plus.bubble")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                vm.addSenseText = """
                                word: \(word.lemma)
                                sense:
                                pos:
                                cefr:
                                ko:
                                example:
                                """
                                vm.showAddSenseSheet = true
                            } label: {
                                Label("sense추가", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.isAddingSense)
                        }
                    }
                }
            }

            Section("Senses") {
                if vm.senses.isEmpty {
                    Text("No senses")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.senseCellList, id: \.id) { cellData in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(cellData.senseCode)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                
                                Text(cellData.tr1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(cellData.tr2)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text("wordId: \(cellData.wordId)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                Text("POS")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField(
                                    "pos",
                                    text: Binding(
                                        get: { vm.posText(for: cellData.senseId) },
                                        set: { vm.setPosText($0, for: cellData.senseId) }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                                .onSubmit {
                                    Task { await vm.savePos(for: cellData.senseId) }
                                }

                                Button {
                                    Task { await vm.savePos(for: cellData.senseId) }
                                } label: {
                                    if vm.isSavingPos(for: cellData.senseId) {
                                        ProgressView()
                                    } else {
                                        Text("저장")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(!vm.canSavePos(for: cellData.senseId))

                                if !cellData.pos.isEmpty {
                                    Text("현재: \(cellData.pos)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            Text(cellData.explain)

                            if !cellData.examples.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Examples")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(Array(cellData.examples.enumerated()), id: \.offset) { _, sentence in
                                        Text("• \(sentence)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(vm.word?.lemma ?? "Word Detail")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let text = vm.formattedCopyText()
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
                    copyStatus = "Copied"
                    showCopyToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopyToast = false
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(vm.word == nil && vm.senses.isEmpty)
            }

            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    vm.showDeleteAllConfirm = true
                } label: {
                    Label("Delete All Senses", systemImage: "trash")
                }
                .disabled(vm.senses.isEmpty || vm.isDeletingAll)
            }

            ToolbarItem(placement: .status) {
                if vm.isDeletingAll || vm.isAddingTranslations || vm.isAddingSense {
                    ProgressView()
                }
            }
        }
        .confirmationDialog(
            "Delete all senses?",
            isPresented: $vm.showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All (\(vm.senses.count))", role: .destructive) {
                Task { await vm.deleteAllSenses() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all senses for this word.")
        }
        .sheet(isPresented: $vm.showAddTranslationsSheet) {
            NavigationStack {
                VStack(spacing: 12) {
                    Text("아래 형식으로 입력하면 블록(빈 줄 기준)마다 sense 순서대로 번역이 추가됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $vm.addTranslationsText)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                        .frame(minHeight: 320)

                    // 원하면 예시 자동 채우기 버튼도 가능
                    // Button("예시 붙여넣기") { vm.addTranslationsText = vm.exampleTemplate() }
                }
                .padding()
                .navigationTitle("번역 추가")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { vm.showAddTranslationsSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("추가") {
                            Task {
                                let ok = await vm.addTranslationsToSenses()
                                if ok { vm.showAddTranslationsSheet = false }
                            }
                        }
                        .disabled(vm.senses.isEmpty || vm.addTranslationsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showAddSenseSheet) {
            NavigationStack {
                VStack(spacing: 12) {
                    Text("아래 형식으로 입력하면 현재 단어에 sense가 추가됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $vm.addSenseText)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                        .frame(minHeight: 260)
                }
                .padding()
                .navigationTitle("sense 추가")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { vm.showAddSenseSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("추가") {
                            Task {
                                let ok = await vm.addSenseToCurrentWord()
                                if ok { vm.showAddSenseSheet = false }
                            }
                        }
                        .disabled(vm.isAddingSense || vm.addSenseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showCopyToast {
                Text(copyStatus)
                    .font(.footnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .task { await vm.load() }
    }
}
