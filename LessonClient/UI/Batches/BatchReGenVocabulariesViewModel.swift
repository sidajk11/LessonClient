import Foundation

@MainActor
final class BatchReGenVocabulariesViewModel: ObservableObject {
    @Published var vocabularyText: String = ""
    @Published var isLoading: Bool = false
    @Published var progressText: String?
    @Published var resultText: String = ""
    @Published var errorMessage: String?

    private let useCase = RegenerateVocabulariesWithoutExamplesUseCase.shared
    private let cutoffDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: 4, day: 2)) ?? .distantFuture
    }()

    func startAll() async {
        guard !isLoading else { return }

        isLoading = true
        progressText = nil
        resultText = ""
        errorMessage = nil
        defer { isLoading = false }

        let result = await useCase.run(cutoffDate: cutoffDate) { [weak self] message in
            self?.progressText = message
        }

        apply(result: result)
    }

    func regenerateInput() async {
        guard !isLoading else { return }

        isLoading = true
        progressText = nil
        resultText = ""
        errorMessage = nil
        defer { isLoading = false }

        let result = await useCase.run(vocabularyInput: vocabularyText, cutoffDate: cutoffDate) { [weak self] message in
            self?.progressText = message
        }

        apply(result: result)
    }

    private func apply(result: RegenerateVocabulariesWithoutExamplesUseCase.Result) {
        resultText = """
        total=\(result.totalVocabularyCount)
        resolvedWords=\(result.resolvedWordCount)
        regeneratedWords=\(result.regeneratedWordCount)
        auditMismatch=\(result.auditMismatchCount)
        auditFailed=\(result.auditFailureCount)
        updatedVocabularies=\(result.updatedVocabularyCount)
        applyFailed=\(result.applyFailureCount)
        """

        if !result.failures.isEmpty {
            errorMessage = result.failures.prefix(5).joined(separator: "\n")
        }
    }
}
