//
//  PronunciationModel.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation

// MARK: - Dialect
enum Dialect: String, Codable {
    case us = "US"
    case uk = "UK"
    case au = "AU"
}

// MARK: - PronunciationRead (response)
struct PronunciationRead: Codable, Identifiable {
    let id: Int
    let wordId: Int
    let senseId: Int?
    let ipa: String
    let dialect: Dialect
    let audioUrl: String?
    let ttsProvider: String?
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case senseId = "sense_id"
        case ipa
        case dialect
        case audioUrl = "audio_url"
        case ttsProvider = "tts_provider"
        case isPrimary = "is_primary"
    }
}

// MARK: - PronunciationCreate (request)
struct PronunciationCreate: Codable {
    let wordId: Int
    let senseId: Int?
    let ipa: String
    let dialect: Dialect
    let audioUrl: String?
    let ttsProvider: String?
    let isPrimary: Bool

    init(
        wordId: Int,
        senseId: Int? = nil,
        ipa: String,
        dialect: Dialect,
        audioUrl: String? = nil,
        ttsProvider: String? = nil,
        isPrimary: Bool = false
    ) {
        self.wordId = wordId
        self.senseId = senseId
        self.ipa = ipa
        self.dialect = dialect
        self.audioUrl = audioUrl
        self.ttsProvider = ttsProvider
        self.isPrimary = isPrimary
    }

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
        case senseId = "sense_id"
        case ipa
        case dialect
        case audioUrl = "audio_url"
        case ttsProvider = "tts_provider"
        case isPrimary = "is_primary"
    }
}

// MARK: - PronunciationUpdate (request)
struct PronunciationUpdate: Codable {
    let wordId: Int?
    let senseId: Int?
    let ipa: String?
    let dialect: Dialect?
    let audioUrl: String?
    let ttsProvider: String?
    let isPrimary: Bool?

    init(
        wordId: Int? = nil,
        senseId: Int? = nil,
        ipa: String? = nil,
        dialect: Dialect? = nil,
        audioUrl: String? = nil,
        ttsProvider: String? = nil,
        isPrimary: Bool? = nil
    ) {
        self.wordId = wordId
        self.senseId = senseId
        self.ipa = ipa
        self.dialect = dialect
        self.audioUrl = audioUrl
        self.ttsProvider = ttsProvider
        self.isPrimary = isPrimary
    }

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
        case senseId = "sense_id"
        case ipa
        case dialect
        case audioUrl = "audio_url"
        case ttsProvider = "tts_provider"
        case isPrimary = "is_primary"
    }
}
