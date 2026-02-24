//
//  PhraseCreateView.swift
//  LessonClient
//
//  Created by Codex on 2/24/26.
//

import SwiftUI

struct PhraseCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PhraseCreateViewModel()
    var onCreated: (() -> Void)? = nil

    var body: some View {
        Form {
            Section("입력") {
                TextEditor(text: $vm.rawText)
                    .frame(minHeight: 220)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Text("""
예)
phrase: Is this
ko: 이것은

phrase: Is this
ko: 이것은
""")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task {
                        do {
                            _ = try await vm.createPhrases()
                            onCreated?()
                            dismiss()
                        } catch {
                            vm.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    if vm.isSaving { ProgressView() } else { Text("생성") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canSubmit)
            }

            if let error = vm.errorMessage {
                Section("오류") {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Phrase 생성")
    }
}

