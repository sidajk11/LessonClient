//
//  SentencePrompts.swift
//  LessonClient
//
//  Created by ym on 3/16/26.
//

import Foundation

extension Prompt {
    static func makeSentencePrompt(topic: String, word: String, cefr: String) -> String {
        """
\(topic) 주제 \(cefr)레벨 영어 문장을 만들어줘 다양한 스타일로 만들어줘 문장만 나열해줘

\(word)
"""
    }
}
