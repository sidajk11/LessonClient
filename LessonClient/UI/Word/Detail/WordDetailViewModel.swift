//
//  WordDetailViewModel.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//  Refactor: bulk example translation via multiline text input
//

import Foundation

@MainActor
final class WordDetailViewModel: ObservableObject {
    let wordId: Int

    // Data
    @Published var word: Word?
    @Published var translationText: String = ""
    @Published var examples: [Example] = []

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

    init(wordId: Int) {
        self.wordId = wordId
    }

    // MARK: - Intents

    func load() async {
        do {
            let w = try await WordDataSource.shared.word(id: wordId)
            word = w
            translationText = w.translation.toString()
            examples = try await ExampleDataSource.shared.examples(wordId: wordId)
            if let lessonId = w.lessonId {
                let unit = try await LessonDataSource.shared.lesson(id: lessonId).unit
                unitText = "\(unit)"
            }
            
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func saveWord() async {
        guard let e = word else { return }
        do {
            let updated = try await WordDataSource.shared.updateWord(
                id: e.id,
                text: e.text,
                lessonId: e.lessonId,
                translation: [LocalizedText].parse(from: translationText)
            )
            word = updated
            info = "기본 텍스트 저장 완료"
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func removeWord() async {
        guard let e = word else { return }
        do {
            try await WordDataSource.shared.deleteWord(id: e.id)
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
            _ = try await LessonDataSource.shared.attachWord(lessonId: target.id, wordId: wid)
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
            let payload: [LocalizedText] = [LocalizedText].parse(from: newSentencetranslationText)

            // 3) Create
            guard let wid = word?.id else { return }
            let created = try await ExampleDataSource.shared.createExample(
                wordId: wid,
                text: newSentence.trimmed,
                translation: payload
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
        editSentence = example.text
        // build bulk text excluding en
        let lines = example.translation
            .filter { $0.langCode.lowercased() != "en" }
            .sorted { $0.langCode < $1.langCode }
            .map { "\($0.langCode): \($0.text)" }
        editSentencetranslationText = lines.joined(separator: "\n")
    }

    func applyEditExample() async {
        guard let ex = editingExample else { return }
        do {
            var payload: [LocalizedText] = [LocalizedText(langCode: "en", text: editSentence.trimmed)]
            let extras = [LocalizedText].parse(from: editSentencetranslationText)
                .filter { $0.langCode.lowercased() != "en" }
            payload.append(contentsOf: extras)

            let updated = try await ExampleDataSource.shared.updateExample(
                id: ex.id,
                translation: payload
            )
            if let idx = examples.firstIndex(where: { $0.id == ex.id }) {
                examples[idx] = updated
            }
            info = "예문이 수정되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func deleteExample(_ id: Int) async {
        do {
            try await ExampleDataSource.shared.deleteExample(id: id)
            examples.removeAll { $0.id == id }
            info = "예문이 삭제되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}


