
import SwiftUI
import Combine

// MARK: - Practice List ViewModel
@MainActor
final class ExerciseListViewModel: ObservableObject {
    let example: Example
    let usePrefetchedExercisesOnly: Bool
    @Published var word: Vocabulary?
    @Published var practices: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init(example: Example, usePrefetchedExercisesOnly: Bool = false) {
        self.example = example
        self.usePrefetchedExercisesOnly = usePrefetchedExercisesOnly
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if let vocabularyId = example.vocabularyId {
                word = try await VocabularyDataSource.shared.vocabulary(id: vocabularyId)
            }

            if usePrefetchedExercisesOnly {
                practices = example.exercises
            } else {
                // Assumes your data source exposes a list method by example
                practices = try await ExerciseDataSource.shared.list(exampleId: example.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func delete() async {
        
    }
}
