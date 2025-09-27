// Models.swift
import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String
}

struct Word: Codable, Identifiable, Hashable {
    let id: Int
    var text: String
    var meanings: [String]
}

struct ExampleItem: Codable, Identifiable {
    let id: Int
    let expression_id: Int
    let sentence_en: String
    let translation: String?
    let lang: String
}

struct Lesson: Codable, Identifiable {
    let id: Int
    var name: String
    var unit: Int
    var level: Int
    var topic: String?
    var grammar_main: String?
    var words: [Word]?
    var expressions: [Expression]?
}

struct Expression: Codable, Identifiable {
    let id: Int
    var text: String
    var meanings: [String]
    // 1:N 스키마 대응 (옵셔널)
    var lessonId: Int?
    var level: Int?
}

