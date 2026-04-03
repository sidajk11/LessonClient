import Foundation

@MainActor
final class SenseGenTestViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var resultText: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let openAIClient = OpenAIClient()

    func submit() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "입력값을 넣어주세요."
            resultText = ""
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        resultText = ""
        defer { isLoading = false }

        do {
            let prompt = Prompt.makeSensePrompt(for: trimmedInput)
            let response = try await openAIClient.generateText(prompt: prompt)
            resultText = response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
