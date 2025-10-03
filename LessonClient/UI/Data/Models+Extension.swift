//
//  Models.swift
//  LessonClient
//
//  Created by ymj on 9/29/25.
//

import SwiftUI

extension Word {
    func translationsText() -> String {
        let text = translations.map { "\($0.langCode): \($0.firstMeaning)" }.joined(separator: "\n")
        return text
    }
}

extension WordTranslation {
    var firstMeaning: String {
        meanings.first?.text ?? ""
    }
}

extension Example {
    func translationsText() -> String {
        let text = translations.map { "\($0.langCode): \($0.text)" }.joined(separator: "\n")
        return text
    }
}

extension Lesson {
    var koTopic: String {
        translations.first(where: { $0.langCode == "ko" })?.topic ?? ""
    }
}

