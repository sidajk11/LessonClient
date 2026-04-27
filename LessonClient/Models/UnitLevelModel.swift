//
//  UnitLevelModel.swift
//  LessonClient
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct UnitLevelRead: Codable, Identifiable, Equatable {
    let id: Int
    var level: Int
    var startUnit: Int

    enum CodingKeys: String, CodingKey {
        case id
        case level
        case startUnit = "start_unit"
    }
}

struct UnitLevelCreate: Codable {
    let level: Int
    let startUnit: Int

    enum CodingKeys: String, CodingKey {
        case level
        case startUnit = "start_unit"
    }
}

struct UnitLevelUpdate: Codable {
    let level: Int?
    let startUnit: Int?

    enum CodingKeys: String, CodingKey {
        case level
        case startUnit = "start_unit"
    }
}
