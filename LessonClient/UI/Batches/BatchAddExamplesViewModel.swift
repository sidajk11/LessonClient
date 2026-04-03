import Foundation

@MainActor
final class BatchAddExamplesViewModel: ObservableObject {
    @Published var topicText: String = ""
    @Published var cefrText: String = ""
    @Published var wordsText: String = ""
    @Published var resultText: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let openAIClient = OpenAIClient()

    func submit() async {
        let topic = topicText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cefr = cefrText.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = wordsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !topic.isEmpty else {
            errorMessage = "토픽을 입력해주세요."
            resultText = ""
            return
        }

        guard !cefr.isEmpty else {
            errorMessage = "cefr 레벨을 입력해주세요."
            resultText = ""
            return
        }

        guard !words.isEmpty else {
            errorMessage = "단어들을 입력해주세요."
            resultText = ""
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        resultText = ""
        defer { isLoading = false }

        do {
            var sections: [String] = []
            sections.reserveCapacity(words.count)

            for word in words {
                let prompt = Prompt.makeSentencePrompt(topic: topic, word: word, cefr: cefr)
                let response = try await openAIClient.generateText(prompt: prompt)
                let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)

                sections.append("""
                [\(word)]
                \(trimmedResponse)
                """)
            }

            resultText = sections.joined(separator: "\n\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
