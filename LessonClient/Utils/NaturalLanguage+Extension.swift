//
//  NaturalLanguage+Extension.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import NaturalLanguage

extension NLTokenizer {
    static func words(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = String(text[tokenRange])
            words.append(word)
            return true
        }

        print(words)
        return words
    }
}

