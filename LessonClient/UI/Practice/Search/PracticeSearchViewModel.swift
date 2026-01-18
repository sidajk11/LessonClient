//
//  PracticeSearchViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/14/25.
//

import Foundation

@MainActor
final class PracticeSearchViewModel: ObservableObject {
    // Inputs
    @Published var q: String = ""
    @Published var levelText: String = ""   // 숫자만
    @Published var unitText: String = ""    // 숫자만

    // State
    @Published var items: [Practice] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

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
            items = try await PracticeDataSource.shared.search(
                q: q,
                level: levelParam,
                unit: unitParam,
                limit: 50
            )
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

