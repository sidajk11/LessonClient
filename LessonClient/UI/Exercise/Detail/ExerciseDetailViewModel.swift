//
//  ExerciseDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import SwiftUI
import Combine

final class ExerciseDetailViewModel: ObservableObject {
    @Published var exercise: Exercise
    @Published var isDeleting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showDeleteConfirm: Bool = false

    init(exercise: Exercise) {
        self.exercise = exercise
    }

    @MainActor
    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        errorMessage = nil
        do {
            try await ExerciseDataSource.shared.delete(id: exercise.id)
            isDeleting = false
            return true
        } catch {
            isDeleting = false
            errorMessage = error.localizedDescription
            return false
        }
    }
}

