import Foundation

@MainActor
final class SentenceUnitCheckViewModel: ObservableObject {
    @Published var sentence = ""
    @Published private(set) var result: SentenceVocabularyAnalysisUseCase.HighestUnitInfo?
    @Published private(set) var emptyResultMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isChecking = false

    private let vocabularyAnalysisUseCase = SentenceVocabularyAnalysisUseCase.shared

    var trimmedSentence: String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func checkHighestUnit() async {
        guard !trimmedSentence.isEmpty, !isChecking else { return }

        isChecking = true
        result = nil
        emptyResultMessage = nil
        errorMessage = nil
        defer { isChecking = false }

        do {
            result = try await vocabularyAnalysisUseCase.highestUnitInfo(in: trimmedSentence)
            if result == nil {
                emptyResultMessage = "문장에서 unit이 연결된 학습 단어를 찾지 못했습니다."
            }
        } catch {
            errorMessage = "문장 unit 검사에 실패했습니다: \(error.localizedDescription)"
        }
    }
}
