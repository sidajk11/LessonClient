// ExampleCreateView.swift

import SwiftUI

struct ExampleCreateView: View {
    let wordId: Int
    var onCreated: ((Example) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ExampleCreateViewModel

    init(wordId: Int, onCreated: ((Example) -> Void)? = nil) {
        self.wordId = wordId
        self.onCreated = onCreated
        _vm = StateObject(wrappedValue: ExampleCreateViewModel(wordId: wordId))
    }

    var body: some View {
        Form {
            Section("문장") {
                TextField("영어 문장", text: $vm.sentence)
                    .autocorrectionDisabled()
            }
            Section("번역들") {
                Text("한 줄에 하나씩 입력하세요.\n예)\nko: 내 가방과 내 휴대폰.\nes: Mi bolsa y mi teléfono.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $vm.translationText)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }

            Button {
                Task {
                    do {
                        let created = try await vm.create()
                        onCreated?(created)
                        dismiss()
                    } catch {
                        vm.error = (error as NSError).localizedDescription
                    }
                }
            } label: {
                if vm.isSaving { ProgressView() } else { Text("생성") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isSaving || vm.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let e = vm.error { Text(e).foregroundStyle(.red) }
        }
        .navigationTitle("새 예문")
    }
}
