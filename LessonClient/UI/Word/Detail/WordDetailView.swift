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
                Section(header: Text("Lemma")) {
                    Text(word.lemma)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            Section(header: Text("Senses")) {
                if vm.senses.isEmpty {
                    Text("No senses")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.senses, id: \.id) { sense in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(sense.translations.map { $0.text }.first ?? "")
                                    .font(.body)
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
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(vm.word?.lemma ?? "Word Detail")
        .task { await vm.load() }
    }

    private func firstLine(of text: String) -> String {
        text.split(separator: "\n").first.map(String.init) ?? text
    }
}

#Preview {
    NavigationStack {
        WordDetailView(wordId: 1)
    }
}
