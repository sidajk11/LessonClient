//
//  Models.swift
//  LessonClient
//
//  Created by ymj on 9/29/25.
//

import SwiftUI

extension String {
    func parseLocalizedString() -> (langCode: String, text: String)? {
        let parts = trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmed }
        guard parts.count == 2 else { return nil }
        return (langCode: parts[0], text: parts[1])
    }
}

extension LessonTranslation {
    func toString() -> String? {
        let text = topic.trimmed
        if text.isEmpty {
            return nil
        }
        return "\(langCode): \(text)"
    }
}

extension WordTranslation {
    func toString() -> String? {
        let text = text.trimmed
        if text.isEmpty {
            return nil
        }
        return "\(langCode): \(text)"
    }
}

extension ExampleTranslation {
    func toString() -> String? {
        let text = text.trimmed
        if text.isEmpty {
            return nil
        }
        return "\(langCode): \(text)"
    }
}

extension ExerciseWordOptionTranslation {
    func toString() -> String? {
        let text = text.trimmed
        if text.isEmpty {
            return nil
        }
        return "\(langCode): \(text)"
    }
}

extension Array where Element == WordTranslation {
    /// Parse multiline text like: "ko: 번역1\nes: texto"
    static func parse(from text: String) -> [Element] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { String($0) }
        return parse(from: lines)
    }
    
    static func parse(from lines: [String]) -> [Element] {
        lines
            .compactMap { $0.parseLocalizedString() }
            .map { Element(langCode: LangCode(rawValue: $0) ?? .ko, text: $1) }
    }

    /// Render to sorted lines "lang: text"
    func toString() -> String {
        self.filter { $0.langCode != .enUS }
            .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
            .compactMap { $0.toString() }
            .joined(separator: "\n")
    }
    
    func koText() -> String {
        self.first(where: { $0.langCode == .ko })?.text ?? ""
    }
}


extension Array where Element == ExampleTranslation {
    /// Parse multiline text like: "ko: 번역1\nes: texto"
    static func parse(from text: String) -> [Element] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { String($0) }
        return parse(from: lines)
    }
    
    static func parse(from lines: [String]) -> [Element] {
        lines
            .compactMap { $0.parseLocalizedString() }
            .map { Element(langCode: LangCode(rawValue: $0) ?? .ko, text: $1) }
    }

    /// Render to sorted lines "lang: text"
    func toString() -> String {
        self.filter { $0.langCode != .enUS }
            .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
            .compactMap { $0.toString() }
            .joined(separator: "\n")
    }
    
    func koText() -> String {
        text(langCode: .ko)
    }
    
    func text(langCode: LangCode) -> String {
        self.first(where: { $0.langCode == langCode })?.text ?? ""
    }
}

extension Array where Element == LessonTranslation {
    /// Parse multiline text like: "ko: 번역1\nes: texto"
    static func parse(from text: String) -> [Element] {
        text
            .components(separatedBy: .newlines)
            .map { String($0) }
            .compactMap { $0.parseLocalizedString() }
            .map { Element(langCode: LangCode(rawValue: $0) ?? .ko, topic: $1) }
    }

    /// Render to sorted lines "lang: text"
    func toString() -> String {
        self.filter { $0.langCode != .enUS }
            .sorted { $0.langCode.rawValue < $1.langCode.rawValue }
            .compactMap { $0.toString() }
            .joined(separator: "\n")
    }
    
    func koText() -> String {
        self.first(where: { $0.langCode == .ko })?.topic ?? ""
    }
}

extension Array where Element == ExerciseTranslation {
    func content(langCode: LangCode) -> String {
        first(where: { $0.langCode == langCode })?.content ?? ""
    }
}

extension Array where Element == ExerciseWordOption {
    func enText() -> String {
        text(langCode: .enUS)
    }
    
    func text(langCode: LangCode) -> String {
        self.map {
            $0.translations.first(where: { $0.langCode == langCode })?.text ?? ""
        }
        .joined(separator: ",")
    }
}
