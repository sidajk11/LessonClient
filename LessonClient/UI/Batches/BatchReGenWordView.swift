import SwiftUI

struct BatchReGenWordView: View {
    @StateObject private var vm = BatchReGenWordViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Words")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $vm.wordText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        }
                }

                Button {
                    Task { await vm.generateInput() }
                } label: {
                    Text("생성")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.regenerateInput() }
                } label: {
                    Text("다시생성")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.regenerate() }
                } label: {
                    Text("다시시작")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)

                Button {
                    vm.stop()
                } label: {
                    if vm.isStopRequested {
                        Text("멈추는 중...")
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("멈추기")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!vm.isLoading || vm.isStopRequested)

                if let progressText = vm.progressText, !progressText.isEmpty {
                    Text(progressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

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
        .navigationTitle("Word 다시 생성")
    }
}
