//
//  WordData.swift
//  LessonClient
//
//  Created by ymj on 9/29/25.
//

import SwiftUI

struct WordData {
    
}

extension LocalizedText {
    static func from(text: String) -> Self? {
        let parts = text.trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmed }
        guard parts.count == 2 else { return nil }
        return Self(langCode: parts[0], text: parts[1])
    }
    
    func toString() -> String? {
        let text = text.trimmed
        if text.isEmpty {
            return nil
        }
        return "\(langCode): \(text)"
    }
}

extension Array where Element == LocalizedText {
    /// Parse multiline text like: "ko: 번역1\nes: texto"
    static func parse(from text: String) -> [LocalizedText] {
        text
            .split(separator: "\n")
            .map { String($0) }
            .compactMap { LocalizedText.from(text: $0) }
    }

    /// Render to sorted lines "lang: text"
    func toString() -> String {
        self.sorted { $0.langCode < $1.langCode }
            .map { "\($0.langCode): \($0.text)" }
            .joined(separator: "\n")
    }
}
