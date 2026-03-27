//
//  ExerciseSearchViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/14/25.
//

import Foundation

@MainActor
final class ExerciseSearchViewModel: ObservableObject {
    // Inputs
    @Published var q: String = ""
    @Published var levelText: String = ""   // 숫자만
    @Published var unitText: String = ""    // 숫자만

    // State
    @Published var items: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var validationErrors: [Int: String] = [:]

    // MARK: - Input sanitizers
    func sanitizeLevel(_ value: String) {
        levelText = value.filter { $0.isNumber }
    }
    func sanitizeUnit(_ value: String) {
        unitText = value.filter { $0.isNumber }
    }

    // MARK: - Search
    func search() async {
        // parse numbers (optional)
        let levelParam: Int? = levelText.isEmpty ? nil : Int(levelText)
        let unitParam: Int?  = unitText.isEmpty  ? nil : Int(unitText)

        if !levelText.isEmpty && levelParam == nil {
            error = "레벨은 숫자로 입력해 주세요."
            return
        }
        if !unitText.isEmpty && unitParam == nil {
            error = "Unit은 숫자로 입력해 주세요."
            return
        }

        do {
            isLoading = true
            defer { isLoading = false }
            items = try await ExerciseDataSource.shared.search(
                q: q,
                level: levelParam,
                unit: unitParam,
                limit: 50
            )
            resetAnswerStates()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    // 옵션 순서를 서버 position 기준으로 고정합니다.
    func orderedOptions(for exercise: Exercise) -> [ExerciseOption] {
        exercise.options.sorted {
            if $0.position == $1.position {
                return $0.id < $1.id
            }
            return $0.position < $1.position
        }
    }

    // correct option도 position 기준으로 맞춰 비교합니다.
    func orderedCorrectOptions(for exercise: Exercise) -> [ExerciseCorrectOption] {
        exercise.correctOptions.sorted {
            if $0.position == $1.position {
                return $0.id < $1.id
            }
            return $0.position < $1.position
        }
    }

    func supportsValidation(for exercise: Exercise) -> Bool {
        exercise.type == .select || exercise.type == .combine
    }

    func validate(exercise: Exercise) {
        let optionIds = orderedOptions(for: exercise).map(\.id)
        let correctOptionIds = orderedCorrectOptions(for: exercise).map(\.optionId)

        switch exercise.type {
        case .select:
            validationErrors[exercise.id] = optionIds.dropLast(1) == correctOptionIds ? nil : "정답오류"
        case .combine:
            validationErrors[exercise.id] = optionIds == correctOptionIds ? nil : "정답오류"
        default:
            break
        }
    }

    // 현재 검색 결과를 한 번에 검사합니다.
    func validateAll() {
        for exercise in items {
            validate(exercise: exercise)
        }
    }

    private func resetAnswerStates() {
        validationErrors = [:]
    }
}
