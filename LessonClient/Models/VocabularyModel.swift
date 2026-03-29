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
    let vocabularyId: Int?
    let phraseId: Int?
    let vocabularyText: String
    let phraseText: String
    let translations: [ExampleSentenceTranslation]
    let exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case id
        case sentence
        case vocabularyId = "vocabulary_id"
        case phraseId = "phrase_id"
        case vocabularyText = "vocabulary_text"
        case phraseText = "phrase_text"
        case translations
        case exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        sentence = try c.decode(String.self, forKey: .sentence)
        vocabularyId = try c.decodeIfPresent(Int.self, forKey: .vocabularyId)
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        vocabularyText = try c.decodeIfPresent(String.self, forKey: .vocabularyText) ?? ""
        phraseText = try c.decodeIfPresent(String.self, forKey: .phraseText) ?? ""
        translations = try c.decodeIfPresent([ExampleSentenceTranslation].self, forKey: .translations) ?? []
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
    }

    init(example: Example) {
        id = example.id
        sentence = example.firstExampleSentence?.text ?? ""
        vocabularyId = example.vocabularyId
        phraseId = example.phraseId
        vocabularyText = example.vocabularyText
        phraseText = example.phraseText
        translations = example.firstExampleSentence?.translations ?? []
        exercises = example.exercises
    }
}

// MARK: - Vocabulary (GET /words/*)
struct Vocabulary: Codable, Identifiable {
    let id: Int
    var lessonId: Int?   // detach 허용 시 서버 nullable
    var unit: Int?       // 서버 응답에 포함되는 unit
    var wordId: Int?
    var formId: Int?
    var senseId: Int?
    var phraseId: Int?
    var text: String
    var cefr: String?
    var difficulty: Int
    var exampleExercise: Bool
    var vocabularyExercise: Bool
    var isForm: Bool
    var translations: [VocabularyTranslation]
    var examples: [VocabularyExampleRead]

    var lessonTargetId: Int? { nil }
    var lessonTarget: LessonTargetRead? { nil }

    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case unit
        case wordId = "word_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case phraseId = "phrase_id"
        case text
        case cefr
        case difficulty
        case exampleExercise = "example_exercise"
        case vocabularyExercise = "vocabulary_exercise"
        case isForm = "is_form"
        case translations
        case examples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        lessonId = try c.decodeIfPresent(Int.self, forKey: .lessonId)
        unit = try c.decodeIfPresent(Int.self, forKey: .unit)
        wordId = try c.decodeIfPresent(Int.self, forKey: .wordId)
        formId = try c.decodeIfPresent(Int.self, forKey: .formId)
        senseId = try c.decodeIfPresent(Int.self, forKey: .senseId)
        phraseId = try c.decodeIfPresent(Int.self, forKey: .phraseId)
        text = try c.decode(String.self, forKey: .text)
        cefr = try c.decodeIfPresent(String.self, forKey: .cefr)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 50
        exampleExercise = try c.decodeIfPresent(Bool.self, forKey: .exampleExercise) ?? true
        vocabularyExercise = try c.decodeIfPresent(Bool.self, forKey: .vocabularyExercise) ?? true
        isForm = try c.decodeIfPresent(Bool.self, forKey: .isForm) ?? true
        translations = try c.decodeIfPresent([VocabularyTranslation].self, forKey: .translations) ?? []
        // 서버가 생략해도 클라이언트에서는 항상 빈 배열로 다룹니다.
        examples = try c.decodeIfPresent([VocabularyExampleRead].self, forKey: .examples) ?? []
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
    let formId: Int?
    let senseId: Int?
    let phraseId: Int?
    let exampleExercise: Bool?
    let vocabularyExercise: Bool?
    let isForm: Bool?
    let translations: [VocabularyTranslation]?

    enum CodingKeys: String, CodingKey {
        case text
        case lessonId = "lesson_id"
        case formId = "form_id"
        case senseId = "sense_id"
        case phraseId = "phrase_id"
        case exampleExercise = "example_exercise"
        case vocabularyExercise = "vocabulary_exercise"
        case isForm = "is_form"
        case translations
    }
    
    init(
        text: String? = nil,
        lessonId: Int? = nil,
        formId: Int? = nil,
        senseId: Int? = nil,
        phraseId: Int? = nil,
        exampleExercise: Bool? = nil,
        vocabularyExercise: Bool? = nil,
        isForm: Bool? = nil,
        translations: [VocabularyTranslation]? = nil
    ) {
        self.text = text
        self.lessonId = lessonId
        self.formId = formId
        self.senseId = senseId
        self.phraseId = phraseId
        self.exampleExercise = exampleExercise
        self.vocabularyExercise = vocabularyExercise
        self.isForm = isForm
        self.translations = translations
    }
}
