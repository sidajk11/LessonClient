//
//  LessonDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

struct LessonTargetRow: Identifiable {
    let id: Int
    let phraseId: Int?
    let text: String
    let wordId: Int?
    let lemma: String
    let senses: [WordSenseRead]
    var selectedSenseId: Int?
    let formId: Int?
    var translation: String

    var selectedSense: WordSenseRead? {
        guard let selectedSenseId else { return nil }
        return senses.first(where: { $0.id == selectedSenseId })
    }

    var selectedSenseCode: String {
        selectedSense?.senseCode ?? "-"
    }

    var selectedSenseKorean: String {
        selectedSense?.translations.first(where: { $0.lang.lowercased() == "ko" })?.text ?? "-"
    }

    var wordDisplayText: String {
        if formId != nil {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? lemma : trimmed
        }
        return lemma
    }
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

    // Vocabularys
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
            let l = try await LessonDataSource.shared.lesson(id: lessonId)
            model = l
            unitText = "\(l.unit)"
            levelText = "\(l.level)"
            grammar = l.grammar ?? ""
            topic = l.translations.koText()
            vocabularys = l.vocabularies
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
            let lessonTargets = buildLessonTargetUpserts()
            let updated = try await LessonDataSource.shared.updateLesson(
                id: lessonId,
                unit: unit,
                level: level,
                grammar: grammar,
                wordIds: nil,
                lessonTargets: lessonTargets,
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
            // Note: let the hosting view handle navigation pop after success if needed.
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func attach(_ wordId: Int) async {
        do {
            let updated = try await LessonDataSource.shared.attachVocabulary(lessonId: lessonId, wordId: wordId)
            model = updated
            vocabularys = updated.vocabularies
            await loadWordRows()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func detach(_ wordId: Int) async {
        do {
            let updated = try await LessonDataSource.shared.detachVocabulary(lessonId: lessonId, wordId: wordId)
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

    func selectSense(wordRowId: Int, senseId: Int) {
        guard let idx = wordRows.firstIndex(where: { $0.id == wordRowId }) else { return }
        wordRows[idx].selectedSenseId = senseId
        wordRows[idx].translation = wordRows[idx].senses
            .first(where: { $0.id == senseId })?
            .translations.first(where: { $0.lang.lowercased() == "ko" })?.text ?? "-"
    }

    func createLessonTargetsFromVocabularies() async {
        guard !isCreatingLessonTargets else { return }
        isCreatingLessonTargets = true
        defer { isCreatingLessonTargets = false }

        do {
            var upserts: [LessonTargetUpsertSchema] = []
            upserts.reserveCapacity(vocabularys.count)

            for (index, vocabulary) in vocabularys.enumerated() {
                let word = try? await WordDataSource.shared.getWord(word: vocabulary.text)
                let forms = try await WordFormDataSource.shared.listWordFormsByForm(form: vocabulary.text, limit: 1)

                let formId = forms.first?.id
                let senseId = word?.senses.first(where: { $0.isPrimary })?.id ?? word?.senses.first?.id
                let targetType: String
                var displayText = word?.lemma
                if formId != nil {
                    targetType = "form"
                    displayText = forms.first?.form
                } else if senseId != nil {
                    targetType = "sense"
                } else {
                    targetType = "word"
                }

                upserts.append(
                    LessonTargetUpsertSchema(
                        targetType: targetType,
                        wordId: word?.id,
                        formId: formId,
                        senseId: senseId,
                        displayText: displayText ?? "",
                        sortIndex: index
                    )
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
        wordRows.enumerated().compactMap { index, row in
            guard let wordId = row.wordId else { return nil }

            let senseId = row.selectedSenseId
            let formId = row.formId
            let targetType: String
            if formId != nil {
                targetType = "form"
            } else if senseId != nil {
                targetType = "sense"
            } else {
                targetType = "word"
            }
            let displayText = formId != nil ? row.text : row.lemma

            return LessonTargetUpsertSchema(
                targetType: targetType,
                wordId: wordId,
                formId: formId,
                senseId: senseId,
                displayText: displayText,
                sortIndex: index
            )
        }
    }

    private func loadWordRows() async {
        isLoadingWordRows = true
        defer { isLoadingWordRows = false }

        var rows: [LessonTargetRow] = []
        let lessonTargets = (model?.lessonTargets ?? []).sorted { $0.sortIndex < $1.sortIndex }
        rows.reserveCapacity(lessonTargets.count)

        for target in lessonTargets {
            do {
                if let formId = target.formId {
                    // form_id 우선: form -> word_id로 역참조해서 로드
                    let form = try await WordFormDataSource.shared.wordForm(id: formId)
                    let word = try await WordDataSource.shared.word(id: form.wordId)
                    let translation = word.senses
                        .first(where: { $0.id == target.senseId })?
                        .translations.first(where: { $0.lang.lowercased() == "ko" })?.text ?? "-"
                    rows.append(
                        LessonTargetRow(
                            id: target.id,
                            phraseId: target.phraseId,
                            text: form.form,
                            wordId: word.id,
                            lemma: word.lemma,
                            senses: word.senses,
                            selectedSenseId: target.senseId,
                            formId: formId,
                            translation: translation
                        )
                    )
                    continue
                }

                if let senseId = target.senseId {
                    // sense_id 우선: 우선 word_id 힌트 사용, 없으면 현재 vocabulary 범위에서 탐색
                    if let wordId = target.wordId {
                        let word = try await WordDataSource.shared.word(id: wordId)
                        let translation = word.senses
                            .first(where: { $0.id == senseId })?
                            .translations.first(where: { $0.lang.lowercased() == "ko" })?.text ?? "-"
                        rows.append(
                            LessonTargetRow(
                                id: target.id,
                                phraseId: target.phraseId,
                                text: target.displayText,
                                wordId: word.id,
                                lemma: word.lemma,
                                senses: word.senses,
                                selectedSenseId: senseId,
                                formId: nil,
                                translation: translation
                            )
                        )
                        continue
                    }

                    var matchedWord: WordRead?
                    for vocabulary in vocabularys {
                        if let word = try? await WordDataSource.shared.getWord(word: vocabulary.text),
                           word.senses.contains(where: { $0.id == senseId }) {
                            matchedWord = word
                            break
                        }
                    }

                    if let word = matchedWord {
                        let translation = word.senses
                            .first(where: { $0.id == senseId })?
                            .translations.first(where: { $0.lang.lowercased() == "ko" })?.text ?? "-"
                        rows.append(
                            LessonTargetRow(
                                id: target.id,
                                phraseId: target.phraseId,
                                text: target.displayText,
                                wordId: word.id,
                                lemma: word.lemma,
                                senses: word.senses,
                                selectedSenseId: senseId,
                                formId: nil,
                                translation: translation
                            )
                        )
                        continue
                    }
                }

                if let wordId = target.wordId {
                    let word = try await WordDataSource.shared.word(id: wordId)
                    let translation = word.senses
                        .first(where: { $0.id == target.senseId })?
                        .translations.first(where: { $0.lang.lowercased() == "ko" })?.text ?? "-"
                    rows.append(
                        LessonTargetRow(
                            id: target.id,
                            phraseId: target.phraseId,
                            text: target.displayText,
                            wordId: word.id,
                            lemma: word.lemma,
                            senses: word.senses,
                            selectedSenseId: target.senseId,
                            formId: target.formId,
                            translation: translation
                        )
                    )
                    continue
                }
            } catch {
                // Fallback to target-only row when fetch fails.
            }

            rows.append(
                LessonTargetRow(
                    id: target.id,
                    phraseId: target.phraseId,
                    text: target.displayText,
                    wordId: target.wordId,
                    lemma: target.displayText,
                    senses: [],
                    selectedSenseId: target.senseId,
                    formId: target.formId,
                    translation: "-"
                )
            )
        }

        wordRows = rows
    }
}
