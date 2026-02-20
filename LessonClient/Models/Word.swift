//
//  Word.swift
//  LessonClient
//
//  Created by ym on 2/12/26.
//

import Foundation

// MARK: - WordSenseTranslation
struct WordSenseTranslation: Codable, Hashable {
    var lang: String
    var text: String
    var explain: String

    enum CodingKeys: String, CodingKey {
        case lang
        case text
        case explain
    }

    init(lang: String, text: String, explain: String) {
        self.lang = lang
        self.text = text
        self.explain = explain
    }
}

// MARK: - WordSenseRead
struct WordSenseRead: Codable, Identifiable {
    var id: Int
    var wordId: Int
    var senseCode: String
    var pos: String?
    var explain: String
    var cefr: String?                 // ✅ 서버: Optional[str]
    var isPrimary: Bool
    var translations: [WordSenseTranslation]
    var examples: [Example]       // ✅ 서버에 존재

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case senseCode = "sense_code"
        case pos
        case explain
        case cefr
        case isPrimary = "is_primary"
        case translations
        case examples
    }

    init(
        id: Int,
        wordId: Int,
        senseCode: String,
        pos: String? = nil,
        explain: String,
        cefr: String? = nil,
        isPrimary: Bool = true,
        translations: [WordSenseTranslation] = [],
        examples: [Example] = []
    ) {
        self.id = id
        self.wordId = wordId
        self.senseCode = senseCode
        self.pos = pos
        self.explain = explain
        self.cefr = cefr
        self.isPrimary = isPrimary
        self.translations = translations
        self.examples = examples
    }
}

// MARK: - WordRead
struct WordRead: Codable, Identifiable {
    var id: Int
    var lemma: String
    var kind: String
    var normalized: String
    var senses: [WordSenseRead]

    enum CodingKeys: String, CodingKey {
        case id
        case lemma
        case kind
        case normalized
        case senses
    }

    init(
        id: Int,
        lemma: String,
        kind: String,
        normalized: String,
        senses: [WordSenseRead] = []
    ) {
        self.id = id
        self.lemma = lemma
        self.kind = kind
        self.normalized = normalized
        self.senses = senses
    }
}

// MARK: - WordCreate
struct WordCreate: Codable, Hashable {
    var lemma: String
    var kind: String

    enum CodingKeys: String, CodingKey {
        case lemma
        case kind
    }

    init(lemma: String, kind: String = "WORD") {
        self.lemma = lemma
        self.kind = kind
    }
}

// MARK: - WordUpdate (✅ 서버에는 pos 없음)
struct WordUpdate: Codable, Hashable {
    var lemma: String?
    var kind: String?

    enum CodingKeys: String, CodingKey {
        case lemma
        case kind
    }

    init(lemma: String? = nil, kind: String? = nil) {
        self.lemma = lemma
        self.kind = kind
    }
}

// MARK: - WordSenseCreate (✅ sense_code 필수)
struct WordSenseCreate: Codable, Hashable {
    var senseCode: String
    var explain: String
    var pos: String?
    var cefr: String?
    var isPrimary: Bool
    var translations: [WordSenseTranslation]?

    enum CodingKeys: String, CodingKey {
        case senseCode = "sense_code"
        case explain
        case pos
        case cefr
        case isPrimary = "is_primary"
        case translations
    }

    init(
        senseCode: String,
        explain: String,
        pos: String? = nil,
        cefr: String? = nil,
        isPrimary: Bool = true,
        translations: [WordSenseTranslation]? = nil
    ) {
        self.senseCode = senseCode
        self.explain = explain
        self.pos = pos
        self.cefr = cefr
        self.isPrimary = isPrimary
        self.translations = translations
    }
}

// MARK: - WordSenseUpdate
struct WordSenseUpdate: Codable, Hashable {
    var senseCode: String?
    var explain: String?
    var pos: String?
    var cefr: String?
    var isPrimary: Bool?
    var translations: [WordSenseTranslation]?

    enum CodingKeys: String, CodingKey {
        case senseCode = "sense_code"
        case explain
        case pos
        case cefr
        case isPrimary = "is_primary"
        case translations
    }

    init(
        senseCode: String? = nil,
        explain: String? = nil,
        pos: String? = nil,
        cefr: String? = nil,
        isPrimary: Bool? = nil,
        translations: [WordSenseTranslation]? = nil
    ) {
        self.senseCode = senseCode
        self.explain = explain
        self.pos = pos
        self.cefr = cefr
        self.isPrimary = isPrimary
        self.translations = translations
    }
}

// MARK: - WordSenseExampleAttachCreate (서버: WordSenseExampleAttachCreate)
struct WordSenseExampleAttachCreate: Codable, Hashable {
    let exampleId: Int
    let isPrime: Bool

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case isPrime = "is_prime"
    }

    init(exampleId: Int, isPrime: Bool = false) {
        self.exampleId = exampleId
        self.isPrime = isPrime
    }
}

struct WordSenseExampleRead: Codable, Equatable, Sendable {
    let senseId: Int
    let exampleId: Int
    let isPrime: Bool

    enum CodingKeys: String, CodingKey {
        case senseId = "sense_id"
        case exampleId = "example_id"
        case isPrime = "is_prime"
    }
}
