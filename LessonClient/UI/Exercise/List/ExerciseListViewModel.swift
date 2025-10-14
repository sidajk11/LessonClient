
import SwiftUI
import Combine

// MARK: - Exercise List ViewModel
@MainActor
final class ExerciseListViewModel: ObservableObject {
    let exampleId: Int
    @Published var exercises: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init(exampleId: Int) {
        self.exampleId = exampleId
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            // Assumes your data source exposes a list method by example
            let result = try await ExerciseDataSource.shared.list(exampleId: exampleId)
            exercises = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
