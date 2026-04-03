import SwiftUI

struct BatchAddExamplesView: View {
    @StateObject private var vm = BatchAddExamplesViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("토픽", text: $vm.topicText)
                    .textFieldStyle(.roundedBorder)

                TextField("CEFR 레벨", text: $vm.cefrText)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text("단어들 (word, word, word ...)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $vm.wordsText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        }
                }

                Button {
                    Task { await vm.submit() }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("확인")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)

                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if !vm.resultText.isEmpty {
                    Text(vm.resultText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle("예문추가")
    }
}
