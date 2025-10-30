//
//  LessonListViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/14/25.
//

import AppKit

@MainActor
final class LessonListViewModel: ObservableObject {
    // Data
    @Published var items: [Lesson] = []

    // UI State
    @Published var unitText: String = ""
    @Published var isCopying: Bool = false
    @Published var copyInfo: String?
    @Published var error: String?

    // MARK: - Load / Search

    func load() async {
        do {
            items = try await LessonDataSource.shared.lessons()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func search() async {
        do {
            let trimmed = unitText.trimmingCharacters(in: .whitespaces)
            let unit = Int(trimmed)
            // 서버: GET /lessons?level=...
            items = try await LessonDataSource.shared.lessons(unit: unit)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func reset() async {
        unitText = ""
        await load()
    }

    // MARK: - Copy / Export

    func copyLessons() async {
        guard isCopying == false else { return }
        isCopying = true
        defer { isCopying = false }
        
        var lessonTextList: [String] = []
        
        for l in items {
            lessonTextList.append(copyLesson(lesson: l))
        }
        
        let text = lessonTextList.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

extension LessonListViewModel {
    private func copyLesson(lesson: Lesson) -> String {
        var lines: [String] = []
        lines.append("\(lesson.unit)")
        lines.append("\n")
        lines.append(lesson.translations.koText())
        lines.append("\n")
        lines.append(lesson.grammar ?? "_")
        lines.append("\n\n")
        for word in lesson.words {
            lines.append(word.text)
            lines.append("\n")
            lines.append(word.translations.toString())
            lines.append("\n\n")
        }
        for word in lesson.words {
            if word.examples.count == 0 {
                continue
            }
            lines.append(word.text)
            lines.append("\n")
            for example in word.examples {
                lines.append(example.text)
                lines.append("\n")
                lines.append(example.translations.toString())
                lines.append("\n\n")
            }
        }
        return lines.joined(separator: "")
    }
}
