import Foundation

@MainActor
final class BatchDeleteLessonsViewModel: ObservableObject {
    @Published var startUnitText: String = ""
    @Published var endUnitText: String = ""
    @Published var isDeleting: Bool = false
    @Published var progressText: String?
    @Published var resultText: String = ""
    @Published var errorMessage: String?

    var canDelete: Bool {
        guard !isDeleting,
              let startUnit = Int(startUnitText),
              let endUnit = Int(endUnitText) else {
            return false
        }
        return startUnit >= 1 && endUnit >= 1 && startUnit <= endUnit
    }

    func sanitizeStartUnit(_ value: String) {
        startUnitText = value.filter(\.isNumber)
    }

    func sanitizeEndUnit(_ value: String) {
        endUnitText = value.filter(\.isNumber)
    }

    func deleteLessons() async {
        errorMessage = nil
        resultText = ""

        guard let startUnit = Int(startUnitText),
              let endUnit = Int(endUnitText),
              startUnit >= 1,
              endUnit >= 1 else {
            errorMessage = "unit은 1 이상의 숫자로 입력해 주세요."
            return
        }

        guard startUnit <= endUnit else {
            errorMessage = "시작 unit은 끝 unit보다 클 수 없습니다."
            return
        }

        isDeleting = true
        progressText = nil
        defer {
            isDeleting = false
            progressText = nil
        }

        var deletedLessonCount = 0
        var emptyUnits: [Int] = []
        var failedRows: [String] = []
        let units = Array(startUnit...endUnit)

        for (index, unit) in units.enumerated() {
            progressText = "레슨 삭제 중... (\(index + 1)/\(units.count)) unit \(unit)"

            do {
                let lessons = try await LessonDataSource.shared.lessons(unit: unit, limit: 200)
                guard !lessons.isEmpty else {
                    emptyUnits.append(unit)
                    continue
                }

                for lesson in lessons {
                    try await LessonDataSource.shared.deleteLesson(id: lesson.id)
                    deletedLessonCount += 1
                }
            } catch {
                failedRows.append("unit \(unit): \((error as NSError).localizedDescription)")
            }
        }

        if failedRows.isEmpty {
            resultText = "삭제 완료: units \(startUnit)~\(endUnit), deleted lessons=\(deletedLessonCount), empty units=\(emptyUnits.count)"
            return
        }

        let preview = failedRows.prefix(3).joined(separator: "\n")
        resultText = "일부 삭제 완료: units \(startUnit)~\(endUnit), deleted lessons=\(deletedLessonCount), failed=\(failedRows.count)"
        errorMessage = """
삭제 중 일부 실패:
\(preview)
"""
    }
}
