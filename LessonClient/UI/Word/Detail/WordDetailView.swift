//
//  WordDetailView.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import SwiftUI

struct WordDetailView: View {
    @StateObject private var vm: WordDetailViewModel

    init(wordId: Int) {
        _vm = StateObject(wrappedValue: WordDetailViewModel(wordId: wordId))
    }

    var body: some View {
        List {
            if let word = vm.word {
                Section("Lemma") {
                    Text(word.lemma)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            Section("Senses") {
                if vm.senses.isEmpty {
                    Text("No senses")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.senses, id: \.id) { sense in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(sense.translations.first?.text ?? "")
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text("s.\(sense.id)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                if let pos = sense.pos, !pos.isEmpty {
                                    Text(pos.uppercased())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(sense.explain)
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
                Button(role: .destructive) {
                    vm.showDeleteAllConfirm = true
                } label: {
                    Label("Delete All Senses", systemImage: "trash")
                }
                .disabled(vm.senses.isEmpty || vm.isDeletingAll)
            }

            ToolbarItem(placement: .status) {
                if vm.isDeletingAll {
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
        .task { await vm.load() }
    }
}


