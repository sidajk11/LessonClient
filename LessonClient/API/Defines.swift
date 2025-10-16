//
//  Defines.swift
//  LessonClient
//
//  Created by ymj on 10/15/25.
//

import Foundation

enum ExerciseType: String, CaseIterable {
    // 단어 선택
    case select
    // 단어 조합
    case combine
    // 단어 입력
    case input
    // 문장 이해
    case comprehend
    
    var name: String {
        switch self {
        case .select:
            "단어 선택"
        case .combine:
            "단어 조합"
        case .input:
            "단어 입력"
        case .comprehend:
            "문장 이해"
        }
    }
    
    var exerciseTitle: String {
        switch self {
        case .select:
            "단어를 선택하세요."
        case .combine:
            "단어를 조합하세요."
        case .input:
            "단어를 입력하세요."
        case .comprehend:
            "답변을 선택하세요."
        }
    }
}


enum LangCode: String, CaseIterable {
    case enGB = "en-GB"
    case enUS = "en-US"     // English (United States)
    case koKR = "ko-KR"     // Korean (South Korea)
    case jaJP = "ja-JP"     // Japanese (Japan)
    case zhCN = "zh-CN"     // Chinese (Simplified, China)
    case zhTW = "zh-TW"     // Chinese (Traditional, Taiwan)
    case frFR = "fr-FR"     // French (France)
    case deDE = "de-DE"     // German (Germany)
    case esES = "es-ES"     // Spanish (Spain)
    case ptBR = "pt-BR"     // Portuguese (Brazil)
    case ruRU = "ru-RU"     // Russian (Russia)
    case itIT = "it-IT"     // Italian (Italy)
    case arSA = "ar-SA"     // Arabic (Saudi Arabia)
    case hiIN = "hi-IN"     // Hindi (India)
    case thTH = "th-TH"     // Thai (Thailand)
    case viVN = "vi-VN"     // Vietnamese (Vietnam)
    case idID = "id-ID"     // Indonesian (Indonesia)
}
