//
//  LessonDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

@MainActor
final class LessonDetailViewModel: ObservableObject {
    let lessonId: Int

    // Lesson
    @Published var model: Lesson?
    @Published var unit: Int = 1
    @Published var level: Int = 1
    @Published var grammar: String = ""

    // Words
    @Published var words: [Word] = []
    @Published var wq: String = ""
    @Published var wsearch: [Word] = []

    // UI state
    @Published var error: String?

    init(lessonId: Int) {
        self.lessonId = lessonId
    }

    // MARK: - Intents

    func load() async {
        do {
            let l = try await LessonDataSource.shared.lesson(id: lessonId)
            model = l
            unit = l.unit
            level = l.level
            grammar = l.grammar ?? ""
            words = l.words
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func save() async {
        do {
            let updated = try await LessonDataSource.shared.updateLesson(
                id: lessonId,
                unit: unit,
                level: level,
                grammar: grammar,
                translations: nil,
                wordIds: nil
            )
            model = updated
            words = updated.words
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func remove() async {
        do {
            try await LessonDataSource.shared.deleteLesson(id: lessonId)
            // Note: let the hosting view handle navigation pop after success if needed.
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func attach(_ wordId: Int) async {
        do {
            let updated = try await LessonDataSource.shared.attachWord(lessonId: lessonId, wordId: wordId)
            model = updated
            words = updated.words
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func detach(_ wordId: Int) async {
        do {
            let updated = try await LessonDataSource.shared.detachWord(lessonId: lessonId, wordId: wordId)
            model = updated
            words = updated.words
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func doWordSearch() async {
        do {
            wsearch = try await WordDataSource.shared.searchWords(q: wq)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
