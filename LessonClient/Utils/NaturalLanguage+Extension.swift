//
//  NaturalLanguage+Extension.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import NaturalLanguage

struct NL {
    static let uppercaseWords = [
        "I", "I'm", "I’m", "I will", "I'll", "I'd", "I've"
    ]
    
    static let abbr = [
        "ID", "TV", "T-shirt", "Wi-Fi"
    ]
    
    static let weekDays = [
        "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
    ]
    
    static let months = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"
    ]
    
    static let names: [String] = [
        "Tom", "Mia"
    ]
    
    static let holidays: [String] = [
        "Christmas", "Eve", "Christmas Day", "New Year's Eve", "Christmas Eve", "New Year's Day"
    ]
    
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
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = sentence

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        var currentName = ""
        var names: [String] = []
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex,
                             unit: .word,
                             scheme: .nameTypeOrLexicalClass,
                             options: options) { tag, range in
            if tag == .personalName || tag == .placeName || tag == .organizationName {
                print("Person name →", sentence[range])
                let token = String(sentence[range])
                if currentName.isEmpty {
                    currentName = token
                } else {
                    currentName += " " + token
                }
                names.append(token)
            } else {
                if !currentName.isEmpty {
                    names.append(currentName)
                    currentName = ""
                }
            }
            return true
        }
        
        if !currentName.isEmpty {
            names.append(currentName)
            currentName = ""
        }
        
        if names.contains(word) {
            return true
        }
        
        if names.contains(word.components(separatedBy: "'").first ?? "") {
            return true
        }
        
        return false
    }
    
    static func lowercaseAvailable(sentence: String, word: String) -> Bool {
        if uppercaseWords.contains(word) {
            return false
        }
        if isName(sentence: sentence, word: word) {
            return false
        }
        
        if names.contains(where: { $0.isSameWord(word: word) }) {
            return false
        }
        
        if weekDays.contains(where: { $0.isSameWord(word: word) }) {
            return false
        }
        
        if months.contains(where: { $0.isSameWord(word: word) }) {
            return false
        }
        
        if abbr.contains(where: { $0.isSameWord(word: word) }) {
            return false
        }
        
        if holidays.contains(where: { $0.isSameWord(word: word) }) {
            return false
        }
        
        return true
    }
    
    static func getLemma(of word: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        let range = word.startIndex..<word.endIndex
        let (lemma, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
        return lemma?.rawValue ?? word
    }
}

