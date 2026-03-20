//
//  VocabularyModel.swift
//  LessonClient
//
//  Created by ym on 3/18/26.
//

import Foundation

struct VocabularyExampleRead: Codable, Identifiable {
    let id: Int
    let sentence: String
    let translations: [ExampleTranslation]
    let exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case id
        case sentence
        case translations
        case exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        sentence = try c.decode(String.self, forKey: .sentence)
        translations = try c.decodeIfPresent([ExampleTranslation].self, forKey: .translations) ?? []
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
    }

    init(example: Example) {
        id = example.id
        sentence = example.sentence
        translations = example.translations
        exercises = example.exercises
    }
}

// MARK: - Vocabulary (GET /words/*)
struct Vocabulary: Codable, Identifiable {
    let id: Int
    var text: String
    var lessonId: Int?   // detach 허용 시 서버 nullable
    var wordId: Int?
    var formId: Int?
    var senseId: Int?
    var phraseId: Int?
    var cefr: String?
    var difficulty: Int
    var exampleExercise: Bool
    var vocabularyExercise: Bool
    var translations: [VocabularyTranslation]
    var examples: [VocabularyExampleRead]?

    var lessonTargetId: Int? { nil }
    var lessonTarget: LessonTargetRead? { nil }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case lessonId = "lesson_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case phraseId = "phrase_id"
        case cefr
        case difficulty
        case exampleExercise = "example_exercise"
        case vocabularyExercise = "vocabulary_exercise"
        case translations
        case examples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        lessonId = try c.decodeIfPresent(Int.self, forKey: .lessonId)
        wordId = try c.decodeIfPresent(Int.self, forKey: .wordId)
        formId = try c.decodeIfPresent(Int.self, forKey: .formId)
        senseId = try c.decodeIfPresent(Int.self, forKey: .senseId)
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        cefr = try c.decodeIfPresent(String.self, forKey: .cefr)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 50
        exampleExercise = try c.decodeIfPresent(Bool.self, forKey: .exampleExercise) ?? true
        vocabularyExercise = try c.decodeIfPresent(Bool.self, forKey: .vocabularyExercise) ?? true
        translations = try c.decodeIfPresent([VocabularyTranslation].self, forKey: .translations) ?? []
        examples = try c.decodeIfPresent([VocabularyExampleRead].self, forKey: .examples)
    }
}

struct VocabularyTranslation: Codable {
    let langCode: LangCode
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}

struct VocabularyUpdate: Codable {
    let text: String?
    let lessonId: Int?           // ✅ lesson_id 선택적
    let wordId: Int?
    let formId: Int?
    let senseId: Int?
    let phraseId: Int?
    let exampleExercise: Bool?
    let vocabularyExercise: Bool?
    let translations: [VocabularyTranslation]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonId = "lesson_id"
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case phraseId = "phrase_id"
        case exampleExercise = "example_exercise"
        case vocabularyExercise = "vocabulary_exercise"
        case translations
    }
    
    init(
        text: String? = nil,
        lessonId: Int? = nil,
        wordId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        phraseId: Int? = nil,
        exampleExercise: Bool? = nil,
        vocabularyExercise: Bool? = nil,
        translations: [VocabularyTranslation]? = nil
    ) {
        self.text = text
        self.lessonId = lessonId
        self.wordId = wordId
        self.formId = formId
        self.senseId = senseId
        self.phraseId = phraseId
        self.exampleExercise = exampleExercise
        self.vocabularyExercise = vocabularyExercise
        self.translations = translations
    }
}
