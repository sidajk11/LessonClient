
import SwiftUI

struct WordCreateView: View {
    var onCreated: ((Word) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = WordCreateViewModel()

    var body: some View {
        Form {
            Section("단어") {
                TextField("단어 (예: my)", text: $vm.text)
                    .autocorrectionDisabled()
                // 필요 시 레슨 연결
                // TextField("레슨 ID (선택)", value: $vm.lessonId, format: .number)
            }

            Section("번역들") {
                TextEditor(text: $vm.translationsText)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Text("예)\nko: 나의 / 내\nes: mi")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    do {
                        let w = try await vm.createWord()
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

            if let e = vm.error {
                Text(e).foregroundStyle(.red)
            }
        }
        .navigationTitle("새 단어")
    }
}
