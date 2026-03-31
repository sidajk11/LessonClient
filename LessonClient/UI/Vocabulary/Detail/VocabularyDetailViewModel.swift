//
//  VocabularyDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//  Refactor: bulk example translation via multiline text input
//

import Foundation

@MainActor
final class VocabularyDetailViewModel: ObservableObject {
    let wordId: Int
    var lesson: Lesson? {
        didSet {
            unitText = "\(lesson?.unit ?? 0)"
        }
    }
    // Data
    @Published var word: Vocabulary?
    @Published var translationText: String = ""
    @Published var examples: [Example] = []
    @Published var senseIdText: String = ""
    @Published var currentSense: WordSenseRead?
    @Published var currentForm: WordFormRead?
    @Published var availableSenses: [WordSenseRead] = []
    @Published var availableForms: [WordFormRead] = []
    @Published var isSenseListExpanded: Bool = false
    @Published var isFormListExpanded: Bool = false
    @Published var isUpdatingSense: Bool = false
    @Published var isUpdatingForm: Bool = false

    // New example input (bulk translation as text)
    @Published var newSentence: String = ""
    @Published var newSentencetranslationText: String = ""   // e.g., "ko: 번역\nes: texto"

    // Edit example (bulk)
    @Published var editingExample: Example?
    @Published var editSentence: String = ""
    @Published var editSentencetranslationText: String = ""   // exclude "en"; en comes from editSentence

    // Attach to lesson by unit (optional UX)
    @Published var unitText: String = ""    // user types unit; we resolve to a lesson and attach

    // UI state
    @Published var error: String?
    @Published var info: String?

    // Derived
    var isCreateDisabled: Bool {
        let sentenceOK = !newSentence.trimmed.isEmpty
        let hasAnyTr = !newSentencetranslationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !(sentenceOK || hasAnyTr)
    }

    var senseCodeText: String {
        currentSense?.senseCode ?? "-"
    }

    var canChangeSense: Bool {
        if let text = word?.text.trimmed, !text.isEmpty {
            return true
        }
        return (word?.wordId ?? currentSense?.wordId) != nil
    }

    var formText: String {
        currentForm?.form ?? "-"
    }

    var canChangeForm: Bool {
        if let text = word?.text.trimmed, !text.isEmpty {
            return true
        }
        return (word?.wordId ?? currentForm?.wordId) != nil
    }

    func koreanText(for sense: WordSenseRead) -> String {
        sense.translations.first {
            let lang = $0.lang.lowercased()
            return lang == "ko" || lang.hasPrefix("ko-")
        }?.text ?? "-"
    }

    init(wordId: Int, lesson: Lesson?) {
        self.wordId = wordId
        self.lesson = lesson
        unitText = "\(lesson?.unit ?? 0)"
    }

    func koreanText(for form: WordFormRead) -> String {
        form.translations.first {
            let lang = $0.lang.lowercased()
            return lang == "ko" || lang.hasPrefix("ko-")
        }?.explain ?? "-"
    }

    // MARK: - Intents

    func load() async {
        do {
            let w = try await VocabularyDataSource.shared.vocabulary(id: wordId)
            word = w
            translationText = w.translations.toString()
            examples = try await ExampleDataSource.shared.examples(wordId: wordId)
            try await loadSelectionMetadata(for: w)
            
            if lesson == nil, let lessonId = w.lessonId {
                lesson = try await LessonDataSource.shared.lesson(id: lessonId)
            }
            
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func saveVocabulary() async {
        guard let e = word else { return }
        do {
            var translations = [VocabularyTranslation].parse(from: translationText)
            translations.append(VocabularyTranslation(langCode: .enUS, text: e.text))
            let updated = try await VocabularyDataSource.shared.updateVocabulary(
                id: e.id,
                text: e.text,
                lessonId: e.lessonId,
                formId: e.formId,
                senseId: e.senseId,
                phraseId: e.phraseId,
                exampleExercise: e.exampleExercise,
                vocabularyExercise: e.vocabularyExercise,
                isForm: e.isForm,
                translations: translations
            )
            word = updated
            try await loadSelectionMetadata(for: updated)
            info = "기본 텍스트 저장 완료"
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func removeVocabulary() async {
        guard let e = word else { return }
        do {
            try await VocabularyDataSource.shared.deleteVocabulary(id: e.id)
            info = "단어가 삭제되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func attachToLesson() async {
        // Resolve by unit; attach this word to the first lesson with that unit
        guard let unit = Int(unitText.trimmingCharacters(in: .whitespacesAndNewlines)), unit > 0 else {
            self.error = "Unit은 숫자여야 합니다."
            return
        }
        do {
            let lessons = try await LessonDataSource.shared.lessons(unit: unit)
            guard let target = lessons.first, let wid = word?.id else {
                self.error = "해당 Unit의 레슨을 찾을 수 없습니다."
                return
            }
            _ = try await LessonDataSource.shared.attachVocabulary(lessonId: target.id, wordId: wid)
            // reload word to reflect lessonId
            await load()
            info = "레슨(#\(target.id))에 연결되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func addExample() async {
        guard word != nil else { return }
        do {
            let payload: [ExampleSentenceTranslation] = [ExampleSentenceTranslation].parse(from: newSentencetranslationText)

            guard let wid = word?.id else { return }
            // Example와 ExampleSentence를 순서대로 생성합니다.
            let createdExample = try await ExampleDataSource.shared.createExample(
                vocabularyId: wid
            )
            _ = try await ExampleSentenceDataSource.shared.createExampleSentence(
                payload: ExampleSentenceCreate(
                    exampleId: createdExample.id,
                    text: newSentence.trimmed,
                    translations: payload
                )
            )
            let refreshedExample = try await ExampleDataSource.shared.example(id: createdExample.id)
            examples.insert(refreshedExample, at: 0)

            // reset
            newSentence = ""
            newSentencetranslationText = ""
            info = "예문이 추가되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func startEdit(example: Example) {
        editingExample = example
        editSentence = example.firstExampleSentence?.text ?? ""
        // build bulk text excluding en
        let translations = example.firstExampleSentence?.translations ?? []
        let lines = translations
            .filter { $0.langCode != .enUS }
            .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
            .map { "\($0.langCode): \($0.text)" }
        editSentencetranslationText = lines.joined(separator: "\n")
    }

    func applyEditExample() async {
        guard let ex = editingExample else { return }
        guard let targetSentence = ex.firstExampleSentence else {
            error = "수정할 ExampleSentence가 없습니다."
            return
        }
        do {
            let payload = [ExampleSentenceTranslation].parse(from: editSentencetranslationText)

            // 대표 문장 수정도 example_sentence 단건 API를 사용합니다.
            _ = try await ExampleSentenceDataSource.shared.updateExampleSentence(
                id: targetSentence.id,
                payload: ExampleSentenceUpdate(
                    text: editSentence.trimmed,
                    translations: payload
                )
            )
            let updated = try await ExampleDataSource.shared.example(id: ex.id)
            if let idx = examples.firstIndex(where: { $0.id == ex.id }) {
                examples[idx] = updated
            }
            info = "예문이 수정되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func detachExample(_ id: Int) async {
        do {
            _ = try await ExampleDataSource.shared.detachExampleFromVocabulary(id: id)
            examples.removeAll { $0.id == id }
            info = "예문 연결이 해제되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func toggleSenseList() async {
        guard let vocabulary = word else { return }

        do {
            try await loadSelectionMetadata(for: vocabulary)
            if availableSenses.isEmpty {
                try await loadAvailableSensesFromWordForm(for: vocabulary)
            }
            guard availableSenses.isEmpty == false else {
                error = "선택 가능한 sense가 없습니다."
                return
            }
            isSenseListExpanded.toggle()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func applySenseId() async {
        let trimmed = senseIdText.trimmed
        guard trimmed.isEmpty == false else {
            error = "sense_id를 입력해 주세요."
            return
        }

        guard let senseId = Int(trimmed), senseId >= 1 else {
            error = "sense_id는 1 이상의 숫자여야 합니다."
            return
        }

        do {
            let sense = try await WordDataSource.shared.wordSense(senseId: senseId)
            await updateSense(to: sense)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func toggleFormList() async {
        guard let vocabulary = word else { return }

        do {
            try await loadSelectionMetadata(for: vocabulary)
            guard availableForms.isEmpty == false else {
                error = "선택 가능한 form이 없습니다."
                return
            }
            isFormListExpanded.toggle()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func updateSense(to sense: WordSenseRead) async {
        guard let vocabulary = word else { return }
        guard isUpdatingSense == false else { return }

        do {
            isUpdatingSense = true
            defer { isUpdatingSense = false }

            let nextFormId: Int?
            if let currentForm, currentForm.wordId != sense.wordId {
                nextFormId = nil
            } else {
                nextFormId = vocabulary.formId
            }

            let updated = try await VocabularyDataSource.shared.updateVocabulary(
                id: vocabulary.id,
                text: vocabulary.text,
                lessonId: vocabulary.lessonId,
                formId: nextFormId,
                senseId: sense.id,
                phraseId: vocabulary.phraseId,
                exampleExercise: vocabulary.exampleExercise,
                vocabularyExercise: vocabulary.vocabularyExercise,
                isForm: vocabulary.isForm,
                translations: vocabulary.translations
            )
            word = updated
            if nextFormId == nil {
                currentForm = nil
            }
            try await loadSelectionMetadata(for: updated)
            info = "sense가 변경되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func updateForm(to form: WordFormRead) async {
        guard let vocabulary = word else { return }
        guard isUpdatingForm == false else { return }

        do {
            isUpdatingForm = true
            defer { isUpdatingForm = false }

            let nextSenseId: Int?
            if let currentSense, currentSense.wordId != form.wordId {
                nextSenseId = nil
            } else {
                nextSenseId = vocabulary.senseId
            }

            let updated = try await VocabularyDataSource.shared.updateVocabulary(
                id: vocabulary.id,
                text: vocabulary.text,
                lessonId: vocabulary.lessonId,
                formId: form.id,
                senseId: nextSenseId,
                phraseId: vocabulary.phraseId,
                exampleExercise: vocabulary.exampleExercise,
                vocabularyExercise: vocabulary.vocabularyExercise,
                isForm: vocabulary.isForm,
                translations: vocabulary.translations
            )
            word = updated
            if nextSenseId == nil {
                currentSense = nil
            }
            try await loadSelectionMetadata(for: updated)
            info = "form이 변경되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func clearForm() async {
        guard let vocabulary = word else { return }
        guard isUpdatingForm == false else { return }
        guard vocabulary.formId != nil else { return }

        do {
            isUpdatingForm = true
            defer { isUpdatingForm = false }

            let updated = try await VocabularyDataSource.shared.replaceVocabulary(
                id: vocabulary.id,
                text: vocabulary.text,
                lessonId: vocabulary.lessonId,
                formId: nil,
                senseId: vocabulary.senseId,
                phraseId: vocabulary.phraseId,
                exampleExercise: vocabulary.exampleExercise,
                vocabularyExercise: vocabulary.vocabularyExercise,
                isForm: vocabulary.isForm,
                translations: vocabulary.translations
            )
            word = updated
            currentForm = nil
            try await loadSelectionMetadata(for: updated)
            info = "form_id가 해제되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func loadSelectionMetadata(for vocabulary: Vocabulary) async throws {
        let wordDataSource = WordDataSource.shared
        let formDataSource = WordFormDataSource.shared

        let lemma = vocabulary.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lemmaWord = try? await wordDataSource.getWord(word: lemma)
        var resolvedCurrentSense: WordSenseRead?
        var resolvedCurrentForm: WordFormRead?

        if let senseId = vocabulary.senseId {
            resolvedCurrentSense = try await wordDataSource.wordSense(senseId: senseId)
        }

        if let formId = vocabulary.formId {
            resolvedCurrentForm = try await formDataSource.wordForm(id: formId)
        }

        let resolvedWordId = lemmaWord?.id
            ?? vocabulary.wordId
            ?? resolvedCurrentSense?.wordId
            ?? resolvedCurrentForm?.wordId

        if let resolvedWordId {
            let resolvedWord: WordRead?
            if let lemmaWord {
                resolvedWord = lemmaWord
            } else {
                resolvedWord = try? await wordDataSource.word(id: resolvedWordId)
            }

            availableSenses = (resolvedWord?.senses ?? [])
                .sorted { lhs, rhs in
                    if lhs.senseCode == rhs.senseCode {
                        return lhs.id < rhs.id
                    }
                    return lhs.senseCode.localizedStandardCompare(rhs.senseCode) == .orderedAscending
                }
            
            if let resolvedCurrentForm {
                let word = try? await wordDataSource.word(id: resolvedCurrentForm.wordId)
                availableSenses = (word?.senses ?? [])
                    .sorted { lhs, rhs in
                        if lhs.senseCode == rhs.senseCode {
                            return lhs.id < rhs.id
                        }
                        return lhs.senseCode.localizedStandardCompare(rhs.senseCode) == .orderedAscending
                    }
            }

            availableForms = try await formDataSource.listWordForms(wordId: resolvedWordId, limit: 200)
                .sorted { lhs, rhs in
                    if lhs.form == rhs.form {
                        return lhs.id < rhs.id
                    }
                    return lhs.form.localizedStandardCompare(rhs.form) == .orderedAscending
                }
            
            if availableForms.isEmpty {
                availableForms = try await formDataSource.listWordFormsByForm(form: lemma)
                    .sorted { lhs, rhs in
                        if lhs.form == rhs.form {
                            return lhs.id < rhs.id
                        }
                        return lhs.form.localizedStandardCompare(rhs.form) == .orderedAscending
                    }
            }
        } else {
            availableSenses = []
            availableForms = []
        }

        if resolvedCurrentSense == nil, let currentSenseId = vocabulary.senseId {
            resolvedCurrentSense = availableSenses.first(where: { $0.id == currentSenseId })
        }

        if resolvedCurrentForm == nil, let currentFormId = vocabulary.formId {
            resolvedCurrentForm = availableForms.first(where: { $0.id == currentFormId })
        }

        currentSense = resolvedCurrentSense
        currentForm = resolvedCurrentForm
        senseIdText = vocabulary.senseId.map(String.init) ?? ""
    }

    private func loadAvailableSensesFromWordForm(for vocabulary: Vocabulary) async throws {
        let formDataSource = WordFormDataSource.shared
        let wordDataSource = WordDataSource.shared

        let candidateForms: [WordFormRead]
        if let currentForm {
            candidateForms = [currentForm]
        } else if let formId = vocabulary.formId,
                  let form = try? await formDataSource.wordForm(id: formId) {
            candidateForms = [form]
        } else {
            let formText = vocabulary.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard formText.isEmpty == false else { return }
            candidateForms = try await formDataSource.listWordFormsByForm(form: formText, limit: 50)
        }

        guard candidateForms.isEmpty == false else { return }

        var sensesById: [Int: WordSenseRead] = [:]
        for wordId in Set(candidateForms.map(\.wordId)).sorted() {
            let word = try await wordDataSource.word(id: wordId)
            for sense in word.senses {
                sensesById[sense.id] = sense
            }
        }

        availableSenses = sensesById.values.sorted { lhs, rhs in
            if lhs.senseCode == rhs.senseCode {
                return lhs.id < rhs.id
            }
            return lhs.senseCode.localizedStandardCompare(rhs.senseCode) == .orderedAscending
        }

        if currentForm == nil {
            if let formId = vocabulary.formId {
                currentForm = candidateForms.first(where: { $0.id == formId })
            } else if candidateForms.count == 1 {
                currentForm = candidateForms.first
            }
        }

        if currentSense == nil, let currentSenseId = vocabulary.senseId {
            currentSense = availableSenses.first(where: { $0.id == currentSenseId })
        }
    }
}
