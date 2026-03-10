//
//  SentenseParser.swift
//  LessonClient
//
//  Created by ym on 3/9/26.
//

import Foundation

struct SentenseParser {
    static func lemmas(in sentence: String) -> [String] {
        let trimmed = sentence.trimmed
        guard !trimmed.isEmpty else { return [] }

        return trimmed
            .tokenize()
            .filter { !punctuationSet.contains($0) }
            .map { NL.getLemma(of: $0, in: sentence) ?? NL.getLemma(of: $0) ?? $0 }
    }
}
