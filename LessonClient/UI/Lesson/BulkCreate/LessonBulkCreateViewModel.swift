//
//  LessonBulkCreateViewModel.swift
//  LessonClient
//
//  Created by Codex on 3/17/26.
//

import Foundation

@MainActor
final class LessonBulkCreateViewModel: ObservableObject {
    @Published var wordListText: String = ""
    @Published var topic: String = ""
    @Published var unitText: String = "1"

    @Published var isSaving: Bool = false
    @Published var isLoadingDefaultUnit: Bool = false
    @Published var error: String?

    let level: Int = 1

    init() {
        Task { await loadDefaultUnit() }
    }

    var parsedWords: [String] {
        Self.parseWords(from: wordListText)
    }

    var lessonCount: Int {
        let count = parsedWords.count
        return count == 0 ? 0 : (count + 1) / 2
    }

    var canSave: Bool {
        guard let unit = Int(unitText) else { return false }
        return unit >= 1 && !topic.trimmed.isEmpty && !parsedWords.isEmpty && !isSaving
    }

    func loadDefaultUnit() async {
        guard isLoadingDefaultUnit == false else { return }
        isLoadingDefaultUnit = true
        defer { isLoadingDefaultUnit = false }

        do {
            unitText = "\(try await LessonDataSource.shared.nextUnit())"
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    func bulkCreate() async throws -> [Lesson] {
        guard let startUnit = Int(unitText), startUnit >= 1 else {
            throw NSError(
                domain: "lesson.bulk.invalid-unit",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "unit 값을 확인해 주세요."]
            )
        }

        let topic = topic.trimmed
        guard topic.isEmpty == false else {
            throw NSError(
                domain: "lesson.bulk.invalid-topic",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "토픽을 입력해 주세요."]
            )
        }

        let words = parsedWords
        guard words.isEmpty == false else {
            throw NSError(
                domain: "lesson.bulk.invalid-words",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "단어 리스트를 입력해 주세요."]
            )
        }

        error = nil
        isSaving = true
        defer { isSaving = false }

        let groupedWords = stride(from: 0, to: words.count, by: 2).map { index in
            Array(words[index..<min(index + 2, words.count)])
        }

        var createdLessons: [Lesson] = []
        createdLessons.reserveCapacity(groupedWords.count)

        for (offset, chunk) in groupedWords.enumerated() {
            let targetUnit = startUnit + offset
            let lesson: Lesson

            if let existingLesson = try await LessonDataSource.shared.lessons(unit: targetUnit, limit: 1).first {
                lesson = existingLesson
            } else {
                lesson = try await LessonDataSource.shared.createLesson(
                    unit: targetUnit,
                    level: level,
                    translations: [LessonTranslation(langCode: .ko, topic: topic)]
                )
            }

            for word in chunk {
                do {
                    if let existingVocabulary = try await findExistingVocabulary(for: word) {
                        if existingVocabulary.lessonId == nil {
                            _ = try await LessonDataSource.shared.attachVocabulary(
                                lessonId: lesson.id,
                                vocabularyId: existingVocabulary.id
                            )
                        }
                        continue
                    }

                    let metadata = try await resolveVocabularyMetadata(for: word)
                    _ = try await VocabularyDataSource.shared.createVocabulary(
                        text: word,
                        lessonId: lesson.id,
                        formId: metadata.formId,
                        senseId: metadata.senseId,
                        phraseId: metadata.phraseId
                    )
                } catch {
                    throw NSError(
                        domain: "lesson.bulk.create-word",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "'\(word)' 추가 중 오류가 발생했습니다. \((error as NSError).localizedDescription)"
                        ]
                    )
                }
            }

            createdLessons.append(try await LessonDataSource.shared.lesson(id: lesson.id))
        }

        return createdLessons
    }

    static func parseWords(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map(\.trimmed)
            .filter { $0.isEmpty == false }
    }

    private func resolveVocabularyMetadata(for word: String) async throws -> VocabularyMetadata {
        async let phraseRows = PhraseDataSource.shared.listPhrases(q: word, limit: 20)
        async let formRowsTask = WordFormDataSource.shared.listWordFormsByForm(form: word, limit: 20)

        let normalizedWord = normalizedLookupKey(for: word)
        let matchedPhrase = try await phraseRows.first {
            matches($0.text, normalizedWord: normalizedWord) || matches($0.normalized, normalizedWord: normalizedWord)
        }
        let formRows = try await formRowsTask
        let matchedForm = formRows.first {
            matches($0.form, normalizedWord: normalizedWord)
        }
        let senseRows: [WordSenseRead]
        if let matchedForm {
            senseRows = try await WordDataSource.shared.listWordSenses(wordId: matchedForm.wordId, limit: 50)
        } else {
            senseRows = try await WordDataSource.shared.listWordSensesByLemma(lemma: word, limit: 50)
        }
        let matchedSense = senseRows.first {
            $0.senseCode.lowercased() == "s1"
        }

        return VocabularyMetadata(
            wordId: matchedSense?.wordId,
            formId: matchedForm?.id,
            senseId: matchedSense?.id,
            phraseId: matchedPhrase?.id
        )
    }

    private func findExistingVocabulary(for word: String) async throws -> Vocabulary? {
        let rows: [Vocabulary]
        do {
            rows = try await VocabularyDataSource.shared.searchVocabularys(q: word, limit: 20)
        } catch APIClient.APIError.http(404, _) {
            return nil
        }
        let normalizedWord = normalizedLookupKey(for: word)
        return rows.first { matches($0.text, normalizedWord: normalizedWord) }
    }

    private func normalizedLookupKey(for text: String) -> String {
        text
            .replacingOccurrences(of: "’", with: "'")
            .trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func matches(_ value: String, normalizedWord: String) -> Bool {
        normalizedLookupKey(for: value) == normalizedWord
    }
}

private struct VocabularyMetadata {
    let wordId: Int?
    let formId: Int?
    let senseId: Int?
    let phraseId: Int?
}
