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
    var sentence_en: String
    var translation_ko: String?
}

struct Lesson: Codable, Identifiable {
    let id: Int
    var name: String
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
}
