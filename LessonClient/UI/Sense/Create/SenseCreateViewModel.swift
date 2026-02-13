//
//  SenseCreateViewModel.swift
//  LessonClient
//
//  Created by ym on 2/12/26.
//

import Foundation

@MainActor
final class SenseCreateViewModel: ObservableObject {
    @Published var rawText: String = ""
    @Published var isSaving: Bool = false
    @Published var statusMessage: String?
    @Published var isError: Bool = false

    @Published private(set) var previewHead: String?
    @Published private(set) var previewSenseCount: Int = 0

    private let dataSource = WordDataSource.shared

    init() {
    }

    func refreshPreview() {
        do {
            let parsed = try SenseBulkParser.parse(rawText)
            previewHead = parsed.head
            previewSenseCount = parsed.items.count
            statusMessage = nil
            isError = false
        } catch {
            previewHead = nil
            previewSenseCount = 0
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func save() async {
        isSaving = true
        statusMessage = nil
        isError = false
        defer { isSaving = false }

        do {
            let parsed = try SenseBulkParser.parse(rawText)

            // 1) 단어 조회(있으면 id 획득), 없으면 생성
            var word: WordRead? = try? await dataSource.findWord(word: parsed.head)
            if word == nil {
                word = try await dataSource.createWord(lemma: parsed.head)
            }
            
            guard let word else { return }
            guard word.senses.count == 0 else {
                return
            }

            var created = 0

            for item in parsed.items {
                let cefr = item.cefr.uppercased()

                // 스키마에 example/cefr 필드가 없으므로 explain에 합쳐서 저장
                var explain = item.sense
                if !item.example.isEmpty {
                    explain += "\nExample: \(item.example)"
                }
                explain += "\nCEFR: \(cefr)"

                let translations: [WordSenseTranslation] = [
                    .init(
                        lang: "ko",
                        text: item.ko,
                        explain: "",       // 필요하면 번역 설명 넣기
                        isPrimary: true
                    )
                ]

                let sense = try await dataSource.createWordSense(wordId: word.id, explain: explain, pos: item.pos, translations: translations)
                let example = try await ExampleDataSource.shared.createExample(sentence: item.example, vocabularyId: nil)
                _ = try await dataSource.attachExampleToWordSense(senseId: sense.id, exampleId: example.id, isPrime: true)
                
                created += 1
            }

            statusMessage = "완료 ✅ word_id=\(word.id) / 생성 \(created)개"
            isError = false
        } catch {
            statusMessage = "실패 ❌ \(error.localizedDescription)"
            isError = true
        }
    }
}

//
// 필요하면 여기서도 추가 가능:
// updateWordSense(senseId:payload:) / deleteWordSense(senseId:)
//

