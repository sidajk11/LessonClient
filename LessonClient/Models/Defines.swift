//
//  Defines.swift
//  LessonClient
//
//  Created by ymj on 10/15/25.
//

import Foundation

enum ExerciseType: String, CaseIterable, Codable {
    // 영어 단어 선택
    case select
    // 번역 단어 선택
    case selectTrans = "select_trans"
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
        case .selectTrans:
            "번역 단어 선택"
        case .combine:
            "단어 조합"
        case .input:
            "단어 입력"
        case .comprehend:
            "문장 이해"
        }
    }
    
    var practiceTitle: String {
        switch self {
        case .select:
            "단어를 선택하세요."
        case .selectTrans:
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


enum LangCode: String, CaseIterable, Codable {
    case enGB = "en-GB"
    case enUS = "en-US"     // English (United States)
    case ko = "ko"     // Korean (South Korea)
    case ja = "ja"     // Japanese (Japan)
    case zhCN = "zh-CN"     // Chinese (Simplified, China)
    case zhTW = "zh-TW"     // Chinese (Traditional, Taiwan)
    case fr = "fr"     // French (France)
    case de = "de"     // German (Germany)
    case es = "es"     // Spanish (Spain)
    case pt = "pt"     // Portuguese (Brazil)
    case ru = "ru"     // Russian (Russia)
    case it = "it"     // Italian (Italy)
    case ar = "ar"     // Arabic (Saudi Arabia)
    case hi = "hi"     // Hindi (India)
    case th = "th"     // Thai (Thailand)
    case vi = "vi"     // Vietnamese (Vietnam)
    case id = "id"     // Indonesian (Indonesia)
}
