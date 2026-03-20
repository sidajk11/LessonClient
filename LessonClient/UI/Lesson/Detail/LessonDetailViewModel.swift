//
//  LessonDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

struct LessonVocabularyRow: Identifiable {
    let id: Int
    let text: String
    let translations: [VocabularyTranslation]
}

struct LessonExerciseRow: Identifiable {
    let id: Int
    let title: String
    let type: String
    let prompt: String?
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
    @Published var vocabularyRows: [LessonVocabularyRow] = []
    @Published var exerciseRows: [LessonExerciseRow] = []
    @Published var isLoadingVocabularies: Bool = false

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
            await reloadDerivedRows()
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
                vocabularyIds: vocabularys.map(\.id),
                translations: [LessonTranslation(langCode: .ko, topic: topic)]
            )
            model = updated
            vocabularys = updated.vocabularies
            await reloadDerivedRows()
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
            applySearchFilter()
            await reloadDerivedRows()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func detach(_ vocabularyId: Int) async {
        do {
            let updated = try await LessonDataSource.shared.detachVocabulary(lessonId: lessonId, vocabularyId: vocabularyId)
            model = updated
            vocabularys = updated.vocabularies
            applySearchFilter()
            await reloadDerivedRows()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func doVocabularySearch() async {
        do {
            let rows = try await VocabularyDataSource.shared.listUnassigned(
                word: wq.isEmpty ? nil : wq
            )
            wsearch = filteredSearchRows(rows)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func reloadDerivedRows() async {
        isLoadingVocabularies = true
        defer { isLoadingVocabularies = false }

        vocabularyRows = vocabularys.map { vocabulary in
            LessonVocabularyRow(
                id: vocabulary.id,
                text: vocabulary.text,
                translations: vocabulary.translations
            )
        }

        let exercisesFromTargets = (model?.lessonTargets ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
            .flatMap(\.exercises)
        let exercisesFromVocabularyExamples = vocabularys
            .flatMap { $0.examples ?? [] }
            .flatMap(\.exercises)
        let allExercises = uniqueExercises(from: exercisesFromTargets + exercisesFromVocabularyExamples)

        exerciseRows = allExercises.map { exercise in
            let vocabularyTexts = exercise.vocabularies
                .map(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let title: String
            if vocabularyTexts.isEmpty {
                let prompt = exercise.prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let prompt, !prompt.isEmpty {
                    title = prompt
                } else {
                    title = exercise.type.rawValue
                }
            } else {
                title = vocabularyTexts.joined(separator: ", ")
            }

            return LessonExerciseRow(
                id: exercise.id,
                title: title,
                type: exercise.type.rawValue,
                prompt: exercise.prompt
            )
        }
    }

    private func uniqueExercises(from exercises: [Exercise]) -> [Exercise] {
        var seen = Set<Int>()
        return exercises.filter { exercise in
            seen.insert(exercise.id).inserted
        }
    }

    private func applySearchFilter() {
        wsearch = filteredSearchRows(wsearch)
    }

    private func filteredSearchRows(_ rows: [Vocabulary]) -> [Vocabulary] {
        let attachedIds = Set(vocabularys.map(\.id))
        return rows.filter { !attachedIds.contains($0.id) }
    }
}
