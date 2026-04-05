//
//  BuildTokenLLMTextUseCase.swift
//  LessonClient
//
//  Created by ym on 4/3/26.
//

import Foundation

// ExampleSentence의 token/sense 정보를 LLM 입력용 텍스트로 조합합니다.
final class BuildTokenLLMTextUseCase {
    static let shared = BuildTokenLLMTextUseCase()

    private let wordDataSource = WordDataSource.shared
    private let formDataSource = WordFormDataSource.shared

    private init() {}
}

extension BuildTokenLLMTextUseCase {
    private enum BuildTokenLLMTextUseCaseError: LocalizedError {
        case fallbackLemmaLookupUsed(surface: String, lemma: String)

        var errorDescription: String? {
            switch self {
            case .fallbackLemmaLookupUsed(let surface, let lemma):
                return "token LLM text 생성 중 lemma fallback 분기를 탔습니다: surface=\(surface), lemma=\(lemma)"
            }
        }
    }

    /// sentence, token_id 목록, sense 후보/예문을 포함한 LLM 입력용 텍스트를 생성합니다.
    func build(exampleSentence: ExampleSentence) async throws -> String {
        let sortedTokens = exampleSentence.tokens.sorted { $0.tokenIndex < $1.tokenIndex }
        let tokenLines = sortedTokens
            .filter { token in
                let trimmed = token.surface.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "’", with: "'")
                return !trimmed.isEmpty && !punctuationSet.contains(trimmed)
            }
            .map { token in
                "token_id:\(token.id) \(token.surface)"
            }
        let searchableTokens = sortedTokens
            .filter { token in
                let trimmed = token.surface.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && !punctuationSet.contains(trimmed)
            }

        var sensesById: [Int: (lemma: String, sense: WordSenseRead)] = [:]

        for token in searchableTokens {
            var surface = token.surface.replacingOccurrences(of: "’", with: "'")
            let isNumber = Int(surface) != nil
            if isNumber {
                surface = numberDict[surface] ?? surface
            }
            //surface로 sense list조회
            // surface로 form조회
            // form.word_id로 sense list 조회
            // 두 list합병해서 ai prompt 생성
            // lemma로 조회해서 sense수집
            let sensesSurface = (try? await wordDataSource.listWordSensesByLemma(lemma: surface, limit: 100)) ?? []
            var lemmaForOutput = surface
            
            // form으로 조회해서 해당 lemma의 sense수집
            var sensesForm: [WordSenseRead] = []
            if let form = try? await formDataSource.listWordFormsByForm(form: surface).first,
               let word = try? await wordDataSource.word(id: form.wordId) {
                sensesForm = word.senses
                lemmaForOutput = word.lemma
            }

            if !sensesForm.isEmpty || !sensesSurface.isEmpty {
                for sense in sensesForm {
                    sensesById[sense.id] = (lemma: lemmaForOutput, sense: sense)
                }

                for sense in sensesSurface {
                    sensesById[sense.id] = (lemma: surface, sense: sense)
                }
            } else {
                throw BuildTokenLLMTextUseCaseError.fallbackLemmaLookupUsed(surface: surface, lemma: "")
            }
        }

        var senseDetailCache: [Int: WordSenseRead] = [:]
        var sensesLines: [String] = []
        for row in sensesById.values.sorted(by: { $0.sense.id < $1.sense.id }) {
            let sense: WordSenseRead
            if !row.sense.examples.isEmpty {
                sense = row.sense
            } else if let cached = senseDetailCache[row.sense.id] {
                sense = cached
            } else if let loaded = try? await wordDataSource.wordSense(senseId: row.sense.id) {
                senseDetailCache[row.sense.id] = loaded
                sense = loaded
            } else {
                sense = row.sense
            }

            let examplesText = sense.examples
                .compactMap { $0.firstExampleSentence?.text }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " | ")

            let line = """
sense_id:\(sense.id) \(row.lemma) (\(sense.senseCode)): \(sense.explain)
sense_examples: \(examplesText.isEmpty ? "-" : examplesText)
"""
            sensesLines.append(line)
        }

        return """
        sentence: \(exampleSentence.text)

        tokens:
        \(tokenLines.isEmpty ? "-" : tokenLines.joined(separator: "\n"))

        senses:
        \(sensesLines.isEmpty ? "-" : sensesLines.joined(separator: "\n"))
        """
    }
}
