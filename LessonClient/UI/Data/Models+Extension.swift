//
//  Models.swift
//  LessonClient
//
//  Created by ymj on 9/29/25.
//

import SwiftUI

extension Example {
    func translationText() -> String {
        let text = translation.map { "\($0.langCode): \($0.text.trimmed)" }.joined(separator: "\n")
        return text
    }
}

extension Lesson {
    var koTopic: String {
        topic.first(where: { $0.langCode == "ko" })?.text ?? ""
    }
}

