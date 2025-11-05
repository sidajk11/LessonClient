//
//  String+Extension.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

let punctuationSet: [String] = [",", ".", "!", "?"]
let names: [String] = ["Tom", "Mia"]

extension String {
    var int: Int? {
        Int(self)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Substring {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension String {
    func tokenize(word: String? = nil) -> [String] {
        var parts: [String] = []

        if let w = word, !w.isEmpty {
            let escaped = NSRegularExpression.escapedPattern(for: w)
            // custom word: 대소문자 무시(i), 공백 무시 끄기(-x)
            parts.append("(?i-x:\(escaped))")
        }

        parts.append("(?:a\\.m\\.|p\\.m\\.)")
        parts.append("[A-Za-z]+(?:'[A-Za-z]+)?")
        parts.append("\\d+(?:\\.\\d+)?")
        parts.append("[.,!?;:()\\[\\]{}\"']")

        let pattern = "(?ix)" + parts.joined(separator: "|")

        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        return regex.matches(in: self, range: range).compactMap { m in
            Range(m.range, in: self).map { String(self[$0]) }
        }
    }
    
    var lastPunctuation: String {
        let tokens = tokenize()
        return tokens.lastPunctuation
    }
    
    var underlinesText: String {
        // 단어 수만큼 "_" 생성, 마지막 문장부호는 그대로 붙여줌
        let tokens = tokenize()
        
        var content: String = ""
        for token in tokens {
            if punctuationSet.contains(token) {
                content.append(token)
            } else {
                if !content.isEmpty {
                    content.append(" ")
                }
                content.append("_")
            }
        }
        
        return content
    }
}

extension Array where Element == String {
    func joinTokens() -> String {
        let noSpaceBefore = punctuationSet  // 앞에 공백이 필요 없는 토큰
        var result = ""
        
        for token in self {
            if result.isEmpty {
                result = token
            } else if noSpaceBefore.contains(token) {
                result += token
            } else {
                result += " " + token
            }
        }
        
        return result
    }
    
    var lastPunctuation: String {
        return reversed().first { punctuationSet.contains($0) } ?? ""
    }
}
