//
//  ExerciseModel.swift
//  LessonClient
//
//  Created by ymj on 10/15/25.
//

struct Exercise: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    var type: ExerciseType
    var wordOptions: [ExerciseWordOption]
    var correctOptionId: Int?
    var options: [ExerciseOption]
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
    var wordOptions: [ExerciseWordOption]?
    var correctOptionId: Int?
    var options: [ExerciseOptionUpdate]?
    var translations: [ExerciseTranslation]?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case type
        case correctOptionId = "correct_option_id"
        case wordOptions = "word_options"
        case options
        case translations
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

struct ExerciseOption: Codable, Identifiable {
    let id: Int
    let translations: [ExerciseOptionTranslation]

    enum CodingKeys: String, CodingKey {
        case id
        case translations
    }
}

struct ExerciseOptionUpdate: Codable {
    let translations: [ExerciseOptionTranslation]?
}

struct ExerciseOptionTranslation: Codable {
    let langCode: LangCode
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}


struct ExerciseWordOption: Codable {
    let translations: [ExerciseOptionTranslation]

    enum CodingKeys: String, CodingKey {
        case translations
    }
}

struct ExerciseWordOptionTranslation: Codable {
    let langCode: LangCode
    var text: String
    
    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case text
    }
}
