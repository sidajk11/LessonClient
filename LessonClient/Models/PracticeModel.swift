//
//  PracticeModel.swift
//  LessonClient
//
//  Created by ymj on 10/15/25.
//

struct Exercise: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    var type: ExerciseType
    var wordOptions: [ExerciseVocabularyOption]
    var correctOptionId: Int?
    var options: [PracticeOption]
    var translations: [ExerciseTranslation]

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case type
        case correctOptionId = "correct_option_id"
        case wordOptions = "word_options"
        case options
        case translations
    }
}

struct ExerciseUpdate: Codable {
    let exampleId: Int
    var type: ExerciseType?
    var wordOptions: [ExerciseVocabularyOption]?
    var correctOptionId: Int?
    var options: [ExerciseOptionUpdate]?
    var translations: [ExerciseTranslation]?
    var correctWordOptionIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case type
        case correctOptionId = "correct_option_id"
        case wordOptions = "word_options"
        case options
        case translations
        case correctWordOptionIds = "correct_word_option_ids"
    }
}

struct ExerciseTranslation: Codable {
    let langCode: LangCode
    var content: String?
    var question: String?
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case content
        case question
    }
}

struct PracticeOption: Codable, Identifiable {
    let id: Int
    let translations: [PracticeOptionTranslation]

    enum CodingKeys: String, CodingKey {
        case id
        case translations
    }
}

struct ExerciseOptionUpdate: Codable {
    let translations: [PracticeOptionTranslation]?
}

struct PracticeOptionTranslation: Codable {
    let langCode: LangCode
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}


struct ExerciseVocabularyOption: Codable {
    let translations: [PracticeOptionTranslation]

    enum CodingKeys: String, CodingKey {
        case translations
    }
}

struct PracticeVocabularyOptionTranslation: Codable {
    let langCode: LangCode
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}
