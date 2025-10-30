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
    @Published var unitText: String = "1"
    @Published var levelText: String = "1"
    @Published var topic: String = ""
    @Published var grammar: String = ""
    @Published var wq: String = ""

    // Words
    @Published var words: [Word] = []
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
            unitText = "\(l.unit)"
            levelText = "\(l.level)"
            grammar = l.grammar ?? ""
            topic = l.translations.koText()
            words = l.words
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func save() async {
        do {
            guard let unit = Int(unitText), let level = Int(levelText) else {
                throw NSError(domain: "form.invalid", code: -1, userInfo: [NSLocalizedDescriptionKey: "입력을 확인해 주세요."])
            }
            let updated = try await LessonDataSource.shared.updateLesson(
                id: lessonId,
                unit: unit,
                level: level,
                grammar: grammar,
                wordIds: nil,
                translations: [LessonTranslation(langCode: .ko, topic: topic)]
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
            if wq.isEmpty {
                wsearch = try await WordDataSource.shared.listUnassigned()
            } else {
                wsearch = try await WordDataSource.shared.searchWords(q: wq)
            }
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
