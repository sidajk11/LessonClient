import Foundation

struct SentenceTokenPhraseMerger {
    struct MergedToken {
        let surface: String
        let phraseId: Int?
    }

    func merge(tokens: [String]) async -> [MergedToken] {
        let queryTokens = Array(
            Set(
                tokens
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !punctuationSet.contains($0) }
                    .map { $0.lowercased() }
            )
        )
        guard !queryTokens.isEmpty else {
            return tokens.map { MergedToken(surface: $0, phraseId: nil) }
        }

        var phraseById: [Int: PhraseRead] = [:]
        for token in queryTokens {
            if let rows = try? await PhraseDataSource.shared.listPhrases(q: token, limit: 200) {
                for row in rows {
                    phraseById[row.id] = row
                }
            }
        }

        let phrasePatterns: [(id: Int, tokens: [String])] = phraseById.values
            .map { (id: $0.id, tokens: $0.text.tokenize()) }
            .filter { $0.tokens.count >= 2 }
            .sorted { lhs, rhs in lhs.tokens.count > rhs.tokens.count }

        guard !phrasePatterns.isEmpty else {
            return tokens.map { MergedToken(surface: $0, phraseId: nil) }
        }

        var merged: [MergedToken] = []
        var i = 0
        while i < tokens.count {
            var matched: (id: Int, tokens: [String])? = nil

            for pattern in phrasePatterns {
                guard i + pattern.tokens.count <= tokens.count else { continue }

                let window = Array(tokens[i..<(i + pattern.tokens.count)])
                let isSame = zip(window, pattern.tokens).allSatisfy { a, b in
                    a.lowercased() == b.lowercased()
                }
                if isSame {
                    matched = (id: pattern.id, tokens: window)
                    break
                }
            }

            if let matched {
                merged.append(.init(surface: matched.tokens.joinTokens(), phraseId: matched.id))
                i += matched.tokens.count
            } else {
                merged.append(.init(surface: tokens[i], phraseId: nil))
                i += 1
            }
        }

        return merged
    }
}
