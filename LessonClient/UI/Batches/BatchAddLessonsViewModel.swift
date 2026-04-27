import Foundation

@MainActor
final class BatchAddLessonsViewModel: ObservableObject {
    struct ParsedVocabulary: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let koTranslation: String
    }

    @Published var topicText: String = ""
    @Published var startUnitText: String = "1"
    @Published var vocabularyListText: String = ""

    @Published var isSaving: Bool = false
    @Published var isLoadingDefaultUnit: Bool = false
    @Published var progressText: String?
    @Published var resultText: String = ""
    @Published var errorMessage: String?

    private let level: Int = 1

    init() {
        Task { await loadDefaultUnit() }
    }

    var parsedVocabularies: [ParsedVocabulary] {
        Self.parseVocabularies(from: vocabularyListText)
    }

    var lessonCount: Int {
        let count = parsedVocabularies.count
        return count == 0 ? 0 : (count + 1) / 2
    }

    var canSave: Bool {
        guard let startUnit = Int(startUnitText) else { return false }
        return startUnit >= 1 &&
            !topicText.trimmed.isEmpty &&
            !parsedVocabularies.isEmpty &&
            !isSaving
    }

    func sanitizeStartUnit(_ value: String) {
        startUnitText = value.filter(\.isNumber)
    }

    func loadDefaultUnit() async {
        guard !isLoadingDefaultUnit else { return }
        isLoadingDefaultUnit = true
        defer { isLoadingDefaultUnit = false }

        do {
            startUnitText = "\(try await LessonDataSource.shared.nextUnit())"
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    func addLessons() async {
        errorMessage = nil
        resultText = ""

        guard let startUnit = Int(startUnitText), startUnit >= 1 else {
            errorMessage = "시작 unit 값을 확인해 주세요."
            return
        }

        let topic = topicText.trimmed
        guard !topic.isEmpty else {
            errorMessage = "토픽을 입력해 주세요."
            return
        }

        let vocabularies = parsedVocabularies
        guard !vocabularies.isEmpty else {
            errorMessage = "vocabulary를 입력해 주세요."
            return
        }

        isSaving = true
        progressText = nil
        defer {
            isSaving = false
            progressText = nil
        }

        let groupedVocabularies = stride(from: 0, to: vocabularies.count, by: 2).map { index in
            Array(vocabularies[index..<min(index + 2, vocabularies.count)])
        }

        var createdLessonCount = 0
        var attachedVocabularyCount = 0

        do {
            for (offset, chunk) in groupedVocabularies.enumerated() {
                let targetUnit = startUnit + offset
                progressText = "레슨 추가 중... (\(offset + 1)/\(groupedVocabularies.count)) unit \(targetUnit)"

                let lesson: Lesson
                if let existingLesson = try await LessonDataSource.shared.lessons(unit: targetUnit, limit: 1).first {
                    lesson = existingLesson
                } else {
                    lesson = try await LessonDataSource.shared.createLesson(
                        unit: targetUnit,
                        level: level,
                        translations: [LessonTranslation(langCode: .ko, topic: topic)]
                    )
                    createdLessonCount += 1
                }

                for vocabulary in chunk {
                    try await upsertVocabulary(vocabulary, lessonId: lesson.id)
                    attachedVocabularyCount += 1
                }
            }

            resultText = "추가 완료: created lessons=\(createdLessonCount), added vocabularies=\(attachedVocabularyCount), target units=\(groupedVocabularies.count)"
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    static func parseVocabularies(from text: String) -> [ParsedVocabulary] {
        text
            .components(separatedBy: .newlines)
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.split(separator: "^", maxSplits: 1, omittingEmptySubsequences: false)
                    .map { String($0).trimmed }
                guard let word = parts.first, !word.isEmpty else { return nil }
                let koTranslation = parts.count > 1 ? parts[1] : ""
                return ParsedVocabulary(text: word, koTranslation: koTranslation)
            }
    }

    private func upsertVocabulary(_ vocabulary: ParsedVocabulary, lessonId: Int) async throws {
        if let existing = try await findExistingVocabulary(for: vocabulary.text) {
            if existing.lessonId == nil {
                _ = try await LessonDataSource.shared.attachVocabulary(
                    lessonId: lessonId,
                    vocabularyId: existing.id
                )
            }

            if !vocabulary.koTranslation.isEmpty {
                let mergedTranslations = mergeKoTranslation(
                    existing.translations,
                    koTranslation: vocabulary.koTranslation
                )
                _ = try await VocabularyDataSource.shared.updateVocabulary(
                    id: existing.id,
                    translations: mergedTranslations
                )
            }
            return
        }

        let metadata = try await resolveVocabularyMetadata(for: vocabulary.text)
        let translations: [VocabularyTranslation]? = vocabulary.koTranslation.isEmpty
            ? nil
            : [VocabularyTranslation(langCode: .ko, text: vocabulary.koTranslation)]

        _ = try await VocabularyDataSource.shared.createVocabulary(
            text: vocabulary.text,
            lessonId: lessonId,
            formId: metadata.formId,
            senseId: metadata.senseId,
            phraseId: metadata.phraseId,
            translations: translations
        )
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

    private func mergeKoTranslation(
        _ translations: [VocabularyTranslation],
        koTranslation: String
    ) -> [VocabularyTranslation] {
        var merged = translations.filter { $0.langCode != .ko }
        merged.append(VocabularyTranslation(langCode: .ko, text: koTranslation))
        return merged
    }

    private func normalizedLookupKey(for text: String) -> String {
        text
            .normalizedApostrophe
            .trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func matches(_ value: String, normalizedWord: String) -> Bool {
        normalizedLookupKey(for: value) == normalizedWord
    }
}

private struct VocabularyMetadata {
    let formId: Int?
    let senseId: Int?
    let phraseId: Int?
}
