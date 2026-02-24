//
//  PronounciationViewModel.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation
import SwiftUI

// 입력 파싱 결과(초안) + 서버 리졸브 결과를 함께 들고 있는 VM용 모델
struct PronunciationDraftItem: Identifiable, Equatable {
    let id = UUID()

    var wordText: String
    var pos: String
    var ipa: String

    // resolved
    var wordId: Int?
    var senseId: Int?
    var resolved: Bool { wordId != nil }
}

@MainActor
final class PronounciationViewModel: ObservableObject {

    // MARK: - Input / Output
    @Published var inputText: String = """
word: and
pos: conjunction
ipa: /ænd/

word: my
pos: determiner
ipa: /maɪ/

word: bag
pos: noun
ipa: /bæɡ/

word: phone
pos: noun
ipa: /foʊn/

word: this
pos: determiner
ipa: /ðɪs/

word: is
pos: verb
ipa: /ɪz/

word: key
pos: noun
ipa: /ki/

word: book
pos: noun
ipa: /bʊk/

word: wallet
pos: noun
ipa: /ˈwɑlət/

word: record
pos: noun
ipa: /ˈrɛkərd/

pos: verb
ipa: /rɪˈkɔrd/
"""

    @Published var items: [PronunciationDraftItem] = []
    @Published var isParsing: Bool = false
    @Published var isResolving: Bool = false
    @Published var isCreating: Bool = false

    @Published var message: String? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Dependencies
    private let wordDS = WordDataSource.shared
    private let pronDS = PronunciationDataSource.shared

    // MARK: - Public Actions

    func parseInput() {
        errorMessage = nil
        message = nil
        isParsing = true
        defer { isParsing = false }

        let parsed = Self.parse(text: inputText)

        if parsed.isEmpty {
            errorMessage = "파싱 결과가 비어있어요. 형식을 확인해 주세요."
            items = []
            return
        }

        items = parsed
        message = "총 \(items.count)개 항목을 파싱했어요."
    }

    func resolveWords() async {
        errorMessage = nil
        message = nil

        if items.isEmpty {
            parseInput()
            if items.isEmpty { return }
        }

        isResolving = true
        defer { isResolving = false }

        // unique word texts
        let uniqueWords = Array(Set(items.map { $0.wordText.lowercased() }))

        // fetch concurrently
        var wordMap: [String: WordRead] = [:]

        do {
            try await withThrowingTaskGroup(of: (String, WordRead).self) { group in
                for w in uniqueWords {
                    group.addTask {
                        // 원문 word casing 유지하고 싶으면 별도 관리 가능
                        let word = try await self.wordDS.getWord(word: w)
                        return (w, word)
                    }
                }

                for try await (w, word) in group {
                    wordMap[w] = word
                }
            }
        } catch {
            errorMessage = "word 조회 실패: \(error.localizedDescription)"
            return
        }

        // 1) wordId 채우기
        var newItems = items
        for idx in newItems.indices {
            let key = newItems[idx].wordText.lowercased()
            if let word = wordMap[key] {
                newItems[idx].wordId = word.id
            } else {
                newItems[idx].wordId = nil
            }
        }

        // 2) senseId 룰 적용:
        // 같은 word가 2개 이상이면 2번째부터 pos 매칭되는 첫 sense id를 넣는다.
        // (pos 매칭은 case-insensitive)
        var occurrence: [String: Int] = [:] // word -> count seen so far

        for idx in newItems.indices {
            let key = newItems[idx].wordText.lowercased()
            occurrence[key, default: 0] += 1
            let n = occurrence[key] ?? 1

            guard n >= 2 else {
                newItems[idx].senseId = nil
                continue
            }

            guard let word = wordMap[key] else {
                newItems[idx].senseId = nil
                continue
            }

            let targetPos = newItems[idx].pos.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // ✅ 여기서 SenseRead의 pos 필드명이 다르면 수정 필요
            if let sense = word.senses.first(where: { $0.pos?.lowercased() == targetPos }) {
                newItems[idx].senseId = sense.id
            } else {
                newItems[idx].senseId = nil
            }
        }

        items = newItems

        // unresolved check
        let unresolved = items.filter { $0.wordId == nil }
        if !unresolved.isEmpty {
            errorMessage = "일부 word를 찾지 못했어요: \(Set(unresolved.map { $0.wordText }))."
        } else {
            message = "모든 word를 조회했고, senseId 룰 적용까지 완료했어요."
        }
    }

    func createPronunciations() async {
        errorMessage = nil
        message = nil

        if items.isEmpty {
            parseInput()
            if items.isEmpty { return }
        }

        // resolve가 안 되어있으면 자동으로 resolve 시도
        if items.contains(where: { $0.wordId == nil }) {
            await resolveWords()
            if items.contains(where: { $0.wordId == nil }) {
                errorMessage = errorMessage ?? "wordId가 없는 항목이 있어 생성할 수 없어요."
                return
            }
        }

        isCreating = true
        defer { isCreating = false }

        // isPrimary: 같은 word 그룹의 첫 항목만 true로 주고 싶으면 아래 방식
        var occurrence: [String: Int] = [:]

        do {
            for item in items {
                let key = item.wordText.lowercased()
                occurrence[key, default: 0] += 1
                let n = occurrence[key] ?? 1

                let isPrimary = (n == 1)

                guard let wordId = item.wordId else { continue }

                _ = try await pronDS.createPronunciation(
                    wordId: wordId,
                    senseId: item.senseId,
                    ipa: item.ipa,
                    dialect: .us,          // ✅ 항상 US
                    audioUrl: nil,
                    ttsProvider: nil,
                    isPrimary: isPrimary
                )
            }

            message = "발음 생성 완료! (\(items.count)개 요청)"
        } catch {
            errorMessage = "발음 생성 실패: \(error.localizedDescription)"
        }
    }
}

// MARK: - Parsing
private extension PronounciationViewModel {
    static func parse(text: String) -> [PronunciationDraftItem] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var results: [PronunciationDraftItem] = []

        var currentWord: String? = nil
        var currentPos: String? = nil

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if line.lowercased().hasPrefix("word:") {
                let value = line.dropFirst("word:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                currentWord = value
                // word를 새로 만나면 pos는 새로 받을 수 있게 리셋해도 되고 유지해도 되는데,
                // 일반적으로는 리셋이 안전
                currentPos = nil
                continue
            }

            if line.lowercased().hasPrefix("pos:") {
                let value = line.dropFirst("pos:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                currentPos = value
                continue
            }

            if line.lowercased().hasPrefix("ipa:") {
                let ipa = line.dropFirst("ipa:".count).trimmingCharacters(in: .whitespacesAndNewlines)

                guard let w = currentWord, !w.isEmpty else {
                    // word 없이 ipa가 오면 무시
                    continue
                }

                let pos = currentPos ?? ""

                results.append(.init(wordText: w, pos: pos, ipa: ipa, wordId: nil, senseId: nil))
                // ipa까지 만들었으면 다음 pos/ipa를 위해 pos는 리셋(같은 word의 두번째 발음 케이스 대비)
                currentPos = nil
                continue
            }

            // 그 외 라인들은 무시(확장 가능)
        }

        // pos가 빈 항목은 senseId 매칭이 어려우니, 필요하면 여기서 필터/검증 가능
        return results
    }
}
