// MARK: - Exercise Create ViewModel

import SwiftUI
import Combine

@MainActor
final class ExerciseCreateViewModel: ObservableObject {
    // Inputs
    @Published var exampleIdText: String = ""
    @Published var type: String = "fill" // change as needed
    @Published var answer: String = ""

    // UI State
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var createdExercise: Exercise?

    // Validation
    var canSubmit: Bool {
        guard Int(exampleIdText) != nil else { return false }
        return !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !isSubmitting
    }

    func submit() async {
        errorMessage = nil
        createdExercise = nil
        guard let exampleId = Int(exampleIdText) else {
            errorMessage = "Example ID must be a number."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let exercise = try await ExerciseDataSource.shared.create(
                exampleId: exampleId,
                type: type,
                answer: answer,
                options: nil,              // add later if your API requires
                translations: nil          // add later if your API requires
            )
            createdExercise = exercise
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

