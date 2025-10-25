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
    @Published var levelText: String = ""
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
            let trimmed = levelText.trimmingCharacters(in: .whitespaces)
            let level = Int(trimmed)
            // 서버: GET /lessons?level=...
            items = try await LessonDataSource.shared.lessons(level: level)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func reset() async {
        levelText = ""
        await load()
    }

    // MARK: - Copy / Export

    func copyLessons() async {
        guard isCopying == false else { return }
        isCopying = true
        defer { isCopying = false }

        // TSV header
        var lines: [String] = ["level\tunit\ttopic(ko)\tgrammar"]
        for l in items {
            let topic = l.translations.koText()
            let grammar = l.grammar ?? ""
            lines.append("\(l.level)\t\(l.unit)\t\(topic)\t\(grammar)")
        }
        let tsv = lines.joined(separator: "\n")

        // Clipboard (macOS / iOS 모두 지원)
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tsv, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = tsv
        #endif

        copyInfo = "\(items.count)개 레슨을 클립보드로 복사했습니다."
    }
}
