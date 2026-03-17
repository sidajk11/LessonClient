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
    @Published var currentSense: WordSenseRead?
    @Published var availableSenses: [WordSenseRead] = []
    @Published var isSenseListExpanded: Bool = false
    @Published var isUpdatingSense: Bool = false

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
        (word?.wordId ?? currentSense?.wordId) != nil
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

    // MARK: - Intents

    func load() async {
        do {
            let w = try await VocabularyDataSource.shared.word(id: wordId)
            word = w
            translationText = w.translations.toString()
            examples = try await ExampleDataSource.shared.examples(wordId: wordId)
            try await loadSenseMetadata(for: w)
            
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
                wordId: e.wordId,
                formId: e.formId,
                senseId: e.senseId,
                phraseId: e.phraseId,
                translations: translations
            )
            word = updated
            try await loadSenseMetadata(for: updated)
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
            let payload: [ExampleTranslation] = [ExampleTranslation].parse(from: newSentencetranslationText)

            // 3) Create
            guard let wid = word?.id else { return }
            let created = try await ExampleDataSource.shared.createExample(
                sentence: newSentence.trimmed,
                vocabularyId: wid,
                translations: payload
            )
            examples.insert(created, at: 0)

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
        editSentence = example.sentence
        // build bulk text excluding en
        let lines = example.translations
            .filter { $0.langCode != .enUS }
            .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
            .map { "\($0.langCode): \($0.text)" }
        editSentencetranslationText = lines.joined(separator: "\n")
    }

    func applyEditExample() async {
        guard let ex = editingExample else { return }
        do {
            let payload = [ExampleTranslation].parse(from: editSentencetranslationText)

            let updated = try await ExampleDataSource.shared.updateExample(
                id: ex.id,
                sentence: editSentence.trimmed,
                translations: payload
            )
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
            try await loadSenseMetadata(for: vocabulary)
            guard availableSenses.isEmpty == false else {
                error = "선택 가능한 sense가 없습니다."
                return
            }
            isSenseListExpanded.toggle()
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

            let updated = try await VocabularyDataSource.shared.updateVocabulary(
                id: vocabulary.id,
                text: vocabulary.text,
                lessonId: vocabulary.lessonId,
                wordId: vocabulary.wordId ?? sense.wordId,
                formId: vocabulary.formId,
                senseId: sense.id,
                phraseId: vocabulary.phraseId,
                translations: vocabulary.translations
            )
            word = updated
            currentSense = sense
            if updated.wordId == nil {
                word?.wordId = sense.wordId
            }
            info = "sense가 변경되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func loadSenseMetadata(for vocabulary: Vocabulary) async throws {
        var resolvedCurrentSense: WordSenseRead?

        if let senseId = vocabulary.senseId {
            resolvedCurrentSense = try await WordDataSource.shared.wordSense(senseId: senseId)
        }

        let resolvedWordId = vocabulary.wordId ?? resolvedCurrentSense?.wordId
        if let resolvedWordId {
            availableSenses = try await WordDataSource.shared.listWordSenses(wordId: resolvedWordId, limit: 200)
                .sorted { lhs, rhs in
                    if lhs.senseCode == rhs.senseCode {
                        return lhs.id < rhs.id
                    }
                    return lhs.senseCode.localizedStandardCompare(rhs.senseCode) == .orderedAscending
                }
        } else {
            availableSenses = []
        }

        if resolvedCurrentSense == nil, let currentSenseId = vocabulary.senseId {
            resolvedCurrentSense = availableSenses.first(where: { $0.id == currentSenseId })
        }

        currentSense = resolvedCurrentSense
    }
}
