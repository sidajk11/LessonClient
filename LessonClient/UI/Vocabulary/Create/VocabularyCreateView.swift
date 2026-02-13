
import SwiftUI

struct VocabularyCreateView: View {
    var onCreated: (([Vocabulary]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = VocabularyCreateViewModel()

    var body: some View {
        Form {
            Button {
                Task {
                    do {
                        let w = try await vm.createVocabulary()
                        onCreated?(w)
                        dismiss()
                    } catch {
                        vm.error = (error as NSError).localizedDescription
                    }
                }
            } label: {
                if vm.isSaving { ProgressView() } else { Text("생성") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canSubmit)
            
            Section("단어&번역들") {
                TextEditor(text: $vm.text)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Text("예)\nko: 나의 / 내\nes: mi")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let e = vm.error {
                Text(e).foregroundStyle(.red)
            }
        }
        .navigationTitle("새 단어")
    }
}
