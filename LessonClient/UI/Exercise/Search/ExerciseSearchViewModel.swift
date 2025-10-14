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
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Presentational helpers
extension Exercise {
    /// 번역 요약(있으면 question/content 우선, 없으면 빈 문자열)
    func translationsSummary() -> String {
        guard !translations.isEmpty else { return "" }
        // question 우선 → 없으면 content → 둘 다 없으면 빈칸
        let parts = translations.compactMap { tr -> String? in
            if let q = tr.question, !q.isEmpty { return "[\(tr.langCode)] \(q)" }
            if let c = tr.content,  !c.isEmpty { return "[\(tr.langCode)] \(c)" }
            return nil
        }
        return parts.joined(separator: "  ·  ")
    }
}
