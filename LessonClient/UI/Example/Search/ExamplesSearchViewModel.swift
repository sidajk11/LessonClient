//
//  ExamplesSearchViewModel.swift
//  LessonClient
//
//  Created by 정영민 on 10/13/25.
//

import Foundation

@MainActor
final class ExamplesSearchViewModel: ObservableObject {
    // Inputs
    @Published var q: String = ""
    @Published var levelText: String = ""   // numeric-only text
    @Published var unitText: String = ""    // numeric-only text

    // State
    @Published var items: [Example] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    func sanitizeLevelInput(_ value: String) {
        levelText = value.filter { $0.isNumber }
    }

    func sanitizeUnitInput(_ value: String) {
        unitText = value.filter { $0.isNumber }
    }

    func search() async {
        let levelParam: Int? = levelText.isEmpty ? nil : Int(levelText)
        let unitParam: Int? = unitText.isEmpty ? nil : Int(unitText)
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
            items = try await ExampleDataSource.shared.search(
                q: q,
                level: levelParam,
                unit: unitParam,
                limit: 30
            )
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
