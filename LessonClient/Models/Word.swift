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
    var isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case lang
        case text
        case explain
        case isPrimary = "is_primary"
    }

    init(
        lang: String,
        text: String,
        explain: String,
        isPrimary: Bool = true
    ) {
        self.lang = lang
        self.text = text
        self.explain = explain
        self.isPrimary = isPrimary
    }
}

// MARK: - WordSenseRead
struct WordSenseRead: Codable, Hashable, Identifiable {
    var id: Int
    var wordId: Int
    var senseCode: String
    var pos: String?
    var explain: String
    var translations: [WordSenseTranslation]

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case senseCode = "sense_code"
        case pos
        case explain
        case translations
    }

    init(
        id: Int,
        wordId: Int,
        senseCode: String,
        pos: String? = nil,
        explain: String,
        translations: [WordSenseTranslation] = []
    ) {
        self.id = id
        self.wordId = wordId
        self.senseCode = senseCode
        self.pos = pos
        self.explain = explain
        self.translations = translations
    }
}

// MARK: - WordRead
struct WordRead: Codable, Hashable, Identifiable {
    var id: Int
    var lemma: String
    var kind: String
    var pos: String?
    var normalized: String
    var senses: [WordSenseRead]

    enum CodingKeys: String, CodingKey {
        case id
        case lemma
        case kind
        case pos
        case normalized
        case senses
    }

    init(
        id: Int,
        lemma: String,
        kind: String,
        pos: String? = nil,
        normalized: String,
        senses: [WordSenseRead] = []
    ) {
        self.id = id
        self.lemma = lemma
        self.kind = kind
        self.pos = pos
        self.normalized = normalized
        self.senses = senses
    }
}

// MARK: - WordUpdate
struct WordUpdate: Codable, Hashable {
    var lemma: String?
    var kind: String?
    var pos: String?

    enum CodingKeys: String, CodingKey {
        case lemma
        case kind
        case pos
    }

    init(
        lemma: String? = nil,
        kind: String? = nil,
        pos: String? = nil
    ) {
        self.lemma = lemma
        self.kind = kind
        self.pos = pos
    }
}

// MARK: - WordSenseCreate
struct WordSenseCreate: Codable, Hashable {
    var senseCode: String?
    var explain: String
    var pos: String?
    var translations: [WordSenseTranslation]?

    enum CodingKeys: String, CodingKey {
        case senseCode = "sense_code"
        case explain
        case pos
        case translations
    }

    init(
        senseCode: String? = nil,
        explain: String,
        pos: String? = nil,
        translations: [WordSenseTranslation]? = nil
    ) {
        self.senseCode = senseCode
        self.explain = explain
        self.pos = pos
        self.translations = translations
    }
}

// MARK: - WordSenseUpdate
struct WordSenseUpdate: Codable, Hashable {
    var senseCode: String?
    var explain: String?
    var pos: String?
    var translations: [WordSenseTranslation]?

    enum CodingKeys: String, CodingKey {
        case senseCode = "sense_code"
        case explain
        case pos
        case translations
    }

    init(
        senseCode: String? = nil,
        explain: String? = nil,
        pos: String? = nil,
        translations: [WordSenseTranslation]? = nil
    ) {
        self.senseCode = senseCode
        self.explain = explain
        self.pos = pos
        self.translations = translations
    }
}


//  WordSenseExampleRead

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
