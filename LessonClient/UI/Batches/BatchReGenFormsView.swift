import SwiftUI

struct BatchReGenFormsView: View {
    @StateObject private var vm = BatchReGenFormsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Vocabulary")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $vm.vocabularyText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        }
                }

                Button {
                    Task { await vm.regenerateInput() }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("생성")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.testCountAfterCutoff() }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("테스트")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.regenerate() }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("다시생성")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)

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
        .navigationTitle("Form 다시 생성")
    }
}
