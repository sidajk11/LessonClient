//
//  LessonDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

struct LessonTargetRow: Identifiable {
    let id: Int
    let vocabularyId: Int?
    let targetType: String
    let displayText: String
    let sortIndex: Int
}

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

    // Vocabularies
    @Published var vocabularys: [Vocabulary] = []
    @Published var wsearch: [Vocabulary] = []
    @Published var wordRows: [LessonTargetRow] = []
    @Published var isLoadingWordRows: Bool = false
    @Published var isCreatingLessonTargets: Bool = false

    // UI state
    @Published var error: String?

    init(lessonId: Int) {
        self.lessonId = lessonId
    }

    // MARK: - Intents

    func load() async {
        do {
            let lesson = try await LessonDataSource.shared.lesson(id: lessonId)
            model = lesson
            unitText = "\(lesson.unit)"
            levelText = "\(lesson.level)"
            grammar = lesson.grammar ?? ""
            topic = lesson.translations.koText()
            vocabularys = lesson.vocabularies
            await loadWordRows()
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
                lessonTargets: buildLessonTargetUpserts(),
                translations: [LessonTranslation(langCode: .ko, topic: topic)]
            )
            model = updated
            vocabularys = updated.vocabularies
            await loadWordRows()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func remove() async {
        do {
            try await LessonDataSource.shared.deleteLesson(id: lessonId)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func attach(_ vocabularyId: Int) async {
        do {
            let updated = try await LessonDataSource.shared.attachVocabulary(lessonId: lessonId, vocabularyId: vocabularyId)
            model = updated
            vocabularys = updated.vocabularies
            await loadWordRows()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func detach(_ vocabularyId: Int) async {
        do {
            let updated = try await LessonDataSource.shared.detachVocabulary(lessonId: lessonId, vocabularyId: vocabularyId)
            model = updated
            vocabularys = updated.vocabularies
            await loadWordRows()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func doVocabularySearch() async {
        do {
            if wq.isEmpty {
                wsearch = try await VocabularyDataSource.shared.listUnassigned()
            } else {
                wsearch = try await VocabularyDataSource.shared.searchVocabularys(q: wq)
            }
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func createLessonTargetsFromVocabularies() async {
        guard !isCreatingLessonTargets else { return }
        isCreatingLessonTargets = true
        defer { isCreatingLessonTargets = false }

        do {
            let upserts = vocabularys.enumerated().map { index, vocabulary in
                LessonTargetUpsertSchema(
                    targetType: "word",
                    vocabularyId: vocabulary.id,
                    displayText: vocabulary.text,
                    sortIndex: index
                )
            }

            let updated = try await LessonDataSource.shared.updateLesson(
                id: lessonId,
                lessonTargets: upserts
            )
            model = updated
            vocabularys = updated.vocabularies
            await loadWordRows()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func buildLessonTargetUpserts() -> [LessonTargetUpsertSchema] {
        wordRows.enumerated().map { index, row in
            LessonTargetUpsertSchema(
                targetType: row.targetType,
                vocabularyId: row.vocabularyId,
                displayText: row.displayText,
                sortIndex: index
            )
        }
    }

    private func loadWordRows() async {
        isLoadingWordRows = true
        defer { isLoadingWordRows = false }

        let lessonTargets = (model?.lessonTargets ?? []).sorted { $0.sortIndex < $1.sortIndex }
        wordRows = lessonTargets.map { target in
            let displayTextFromVocabulary = target.vocabularyId
                .flatMap { vocabularyId in vocabularys.first(where: { $0.id == vocabularyId })?.text }
            return LessonTargetRow(
                id: target.id,
                vocabularyId: target.vocabularyId,
                targetType: target.targetType,
                displayText: displayTextFromVocabulary ?? target.displayText,
                sortIndex: target.sortIndex
            )
        }
    }
}
