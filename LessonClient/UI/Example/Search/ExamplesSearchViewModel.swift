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
    @Published var levelCode: String = ""   // e.g., "1", "A1"
    @Published var unitText: String = ""    // numeric-only text
    @Published var lang: String = "ko"

    // State
    @Published var items: [Example] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    func sanitizeUnitInput(_ value: String) {
        unitText = value.filter { $0.isNumber }
    }

    func search() async {
        let unitParam: Int? = unitText.isEmpty ? nil : Int(unitText)
        if !unitText.isEmpty && unitParam == nil {
            error = "Unit은 숫자로 입력해 주세요."
            return
        }

        do {
            isLoading = true
            defer { isLoading = false }
            items = try await ExampleDataSource.shared.search(
                q: q,
                levelCode: levelCode.isEmpty ? nil : levelCode,
                unitNumber: unitParam,
                lang: lang.isEmpty ? "ko" : lang,
                limit: 30
            )
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
