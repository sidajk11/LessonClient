//
//  ExerciseModel.swift
//  LessonClient
//
//  Created by ymj on 10/15/25.
//

struct Exercise: Codable, Identifiable {
    let id: Int
    let exampleId: Int
    var info: [ExerciseInfo]
    var type: String
    var words: String
    var correctOptionId: Int?
    var options: [ExerciseOption]

    enum CodingKeys: String, CodingKey {
        case id
        case exampleId = "example_id"
        case type
        case correctOptionId = "correct_option_id"
        case words
        case options
        case info
    }
}

struct ExerciseUpdate: Codable {
    let exampleId: Int
    var info: [ExerciseInfo]?
    var type: String?
    var words: String?
    var correctOptionId: Int?
    var options: [ExerciseOptionUpdate]?

    enum CodingKeys: String, CodingKey {
        case exampleId = "example_id"
        case type
        case correctOptionId = "correct_option_id"
        case words
        case options
        case info
    }
}

struct ExerciseInfo: Codable {
    let langCode: String
    var content: String
    var question: String

    enum CodingKeys: String, CodingKey {
        case langCode = "lang_code"
        case content
        case question
    }
}

struct ExerciseOption: Codable, Identifiable {
    let id: Int
    let translation: [LocalizedText]

    enum CodingKeys: String, CodingKey {
        case id
        case translation
    }
}

struct ExerciseOptionUpdate: Codable {
    let translation: [LocalizedText]?
}
