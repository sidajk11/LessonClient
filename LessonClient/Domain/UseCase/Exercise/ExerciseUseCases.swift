//
//  ExerciseUseCases.swift
//  LessonClient
//
//  Created by ym on 3/30/26.
//

import Foundation

struct ExerciseUseCases {
    static let shared = ExerciseUseCases(
        generateExercise: GenerateExerciseUseCase.shared
    )
    
    let generateExercise: GenerateExerciseUseCase
}
