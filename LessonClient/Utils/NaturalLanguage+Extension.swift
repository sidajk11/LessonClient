//
//  NaturalLanguage+Extension.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import NaturalLanguage

struct NL {
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
    
    static func isName(sentence: String, word: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]

        var names: [String] = []
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex,
                             unit: .word,
                             scheme: .nameType,
                             options: options) { tag, range in
            if tag == .personalName {
                print("Person name →", sentence[range])
                names.append(String(sentence[range]))
            }
            return true
        }
        return names.contains(word)
    }
    
    static func lowercaseAvailable(sentence: String, word: String) -> Bool {
        if word == "I" {
            return false
        }
        if isName(sentence: sentence, word: word) {
            return false
        }
        
        return true
    }
}

