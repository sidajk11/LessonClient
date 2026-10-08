import SwiftUI

struct SentenceUnitCheckView: View {
    @StateObject private var viewModel = SentenceUnitCheckViewModel()
    @FocusState private var isSentenceFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("영어 문장을 입력하면 문장에 포함된 학습 단어 중 가장 높은 unit을 확인합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $viewModel.sentence)
                    .font(.body)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 1)
                    }
                    .focused($isSentenceFocused)

                HStack {
                    Button("검사") {
                        Task { await viewModel.checkHighestUnit() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isChecking || viewModel.trimmedSentence.isEmpty)

                    if viewModel.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                resultView
            }
            .padding()
        }
        .navigationTitle("문장유닛검사")
        .onAppear {
            isSentenceFocused = true
        }
    }

    @ViewBuilder
    private var resultView: some View {
        if let result = viewModel.result {
            VStack(alignment: .leading, spacing: 6) {
                Text("최고 unit")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Unit \(result.unit)")
                    .font(.system(size: 32, weight: .bold))
                Text("해당 단어: \(result.vocabularyText)")
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let message = viewModel.emptyResultMessage {
            Text(message)
                .foregroundStyle(.secondary)
        }

        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
        }
    }
}
