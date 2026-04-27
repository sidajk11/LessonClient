//
//  String+Extension.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

import Foundation

let punctuationSet: [String] = [",", ".", "!", "?", ":", "$"]

let expressions = [
    "Christmas Day", "New Year's Eve", "Christmas Eve", "New Year's Day",
    "New York City"
]

let numberDict: [String: String] = [
    "1": "one", "2": "two", "3": "three", "4": "four", "5": "five",
    "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten",
    "11": "eleven", "12": "twelve", "13": "thirteen", "14": "fourteen", "15": "fifteen",
    "16": "sixteen", "17": "seventeen", "18": "eighteen", "19": "nineteen", "20": "twenty",
    "21": "twenty-one", "22": "twenty-two", "23": "twenty-three", "24": "twenty-four", "25": "twenty-five",
    "26": "twenty-six", "27": "twenty-seven", "28": "twenty-eight", "29": "twenty-nine", "30": "thirty"
]

extension String {
    var int: Int? {
        Int(self)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var normalizedApostrophe: String {
        replacingOccurrences(of: "’", with: "'")
    }
}

extension Substring {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension String {
    func tokenize(word: String? = nil) -> [String] {
        var parts: [String] = []

        var words: [String] = []
        if let word {
            words.append(word)
        }
        words.append(contentsOf: expressions)
        
        for w in words where !w.isEmpty && w.contains(" ") {
            let escaped = NSRegularExpression.escapedPattern(for: w)
            // custom word: 대소문자 무시(i), 공백 무시 끄기(-x)
            parts.append("(?i-x:\(escaped))")
        }

        parts.append("(?:a\\.m\\.|p\\.m\\.)")
        parts.append("[\\p{L}\\p{M}]+(?:[\\p{Pd}'’][\\p{L}\\p{M}]+)*(?:['’])?")
        parts.append("\\d+(?:\\.\\d+)?")
        parts.append("[$.,!?;:()\\[\\]{}\"']")

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

extension String {
    func isSameWord(word: String) -> Bool {
        let wordA = NL.getLemma(of: self)?.lowercased() ?? self
        let wordB = NL.getLemma(of: word)?.lowercased() ?? word
        let result = wordA == wordB
        if !result, word.contains(self) {
            if word == self + "s" {
                return true
            }
        }
        return result
    }
}

extension Array where Element == String {
    func joinTokens() -> String {
        let noSpaceBefore = punctuationSet  // 앞에 공백이 필요 없는 토큰
        let noSpaceAfter = ["$"]            // 뒤에 공백이 필요 없는 토큰
        var result = ""
        
        for token in self {
            if result.isEmpty {
                result = token
            } else if noSpaceAfter.contains(String(result.suffix(1))) {
                result += token
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
    
    func subtractingWords(_ other: [String]) -> [String] {
        
        var list: [String] = []
        list = self
        list.removeAll(where: { word in
            other.contains(where: {
                $0.isSameWord(word: word)
            })
        } )
        return list
    }
}
