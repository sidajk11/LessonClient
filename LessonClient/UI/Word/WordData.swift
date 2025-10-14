//
//  WordData.swift
//  LessonClient
//
//  Created by ymj on 9/29/25.
//

import SwiftUI

struct WordData {
    
}

extension WordTranslation {
    static func from(text: String) -> Self? {
        let parts = text.trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmed }
        guard parts.count == 2 else { return nil }
        return WordTranslation(langCode: parts[0], text: parts[1])
    }
    
    func toString() -> String? {
        let text = text.trimmed
        if text.isEmpty {
            return nil
        }
        return "\(langCode): \(text)"
    }
}

extension ExampleTranslation {
    static func from(text: String) -> ExampleTranslation? {
        let parts = text.trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmed }
        guard parts.count == 2 else { return nil }
        return ExampleTranslation(langCode: parts[0], text: parts[1])
    }
}

extension Array where Element == WordTranslation {
    /// 주어진 텍스트(예: "ko: 나의 / 내\nes: mi")를 파싱해 [WordTranslation] 생성
    static func parse(from text: String) -> [WordTranslation] {
        return text
            .split(separator: "\n")
            .map { String($0) }
            .compactMap { line -> WordTranslation? in
                return WordTranslation.from(text: line)
            }
    }
    
    func toString() -> String {
        let items = self.sorted { $0.langCode < $1.langCode }

        return items.compactMap { $0.toString() }
        .joined(separator: "\n")
    }
}


extension Array where Element == ExampleTranslation {
    /// Parse multiline text like: "ko: 번역1\nes: texto"
    static func parse(from text: String) -> [ExampleTranslation] {
        text
            .split(separator: "\n")
            .map { String($0) }
            .compactMap { ExampleTranslation.from(text: $0) }
    }

    /// Render to sorted lines "lang: text"
    func toString() -> String {
        self.sorted { $0.langCode < $1.langCode }
            .map { "\($0.langCode): \($0.text)" }
            .joined(separator: "\n")
    }
}
