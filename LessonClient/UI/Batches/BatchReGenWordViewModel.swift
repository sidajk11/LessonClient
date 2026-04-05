import Foundation

@MainActor
final class BatchReGenWordViewModel: ObservableObject {
    @Published var wordText: String = ""
    @Published var isLoading: Bool = false
    @Published var isStopRequested: Bool = false
    @Published var progressText: String?
    @Published var resultText: String = ""
    @Published var errorMessage: String?

    private let useCase = RegenerateWordsBeforeDateUseCase.shared
    private var shouldStop: Bool = false
    private let cutoffDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: 4, day: 2)) ?? .distantFuture
    }()

    func regenerate() async {
        guard !isLoading else { return }

        prepareRun()

        let result = await useCase.run(
            cutoffDate: cutoffDate,
            onProgress: { [weak self] message in
                self?.progressText = message
            },
            shouldContinue: { [weak self] in
                !(self?.shouldStop ?? false)
            }
        )

        finish(result: result)
    }

    func generateInput() async {
        guard !isLoading else { return }

        prepareRun()

        let result = await useCase.run(
            wordInput: wordText,
            cutoffDate: cutoffDate,
            deleteExistingWord: false,
            onProgress: { [weak self] message in
                self?.progressText = message
            },
            shouldContinue: { [weak self] in
                !(self?.shouldStop ?? false)
            }
        )

        finish(result: result)
    }

    func regenerateInput() async {
        guard !isLoading else { return }

        prepareRun()

        let result = await useCase.run(
            wordInput: wordText,
            cutoffDate: cutoffDate,
            deleteExistingWord: true,
            onProgress: { [weak self] message in
                self?.progressText = message
            },
            shouldContinue: { [weak self] in
                !(self?.shouldStop ?? false)
            }
        )

        finish(result: result)
    }

    func stop() {
        guard isLoading else { return }
        shouldStop = true
        isStopRequested = true
        progressText = "현재 작업 마무리 후 멈추는 중..."
    }

    private func prepareRun() {
        isLoading = true
        isStopRequested = false
        shouldStop = false
        progressText = nil
        resultText = ""
        errorMessage = nil
    }

    private func finish(result: RegenerateWordsBeforeDateUseCase.Result) {
        defer { isLoading = false }

        resultText = """
        total=\(result.totalWordCount)
        eligible=\(result.eligibleWordCount)
        regenerated=\(result.regeneratedWordCount)
        """

        if result.wasStopped {
            progressText = "중지됨"
        }

        if !result.failures.isEmpty {
            errorMessage = result.failures.prefix(5).joined(separator: "\n")
        }
    }
}
