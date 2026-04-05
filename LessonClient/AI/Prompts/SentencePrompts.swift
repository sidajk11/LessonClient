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
\(topic) 주제로 
\(cefr)레벨 영어 문장을 만들어줘 
다양한 스타일로 만들어줘 
다양한 주어, 술어, 보어, 목적어
번호 없이 문장만 나열해줘 
최대 10개
등장 인물: Mia, Emma로 문장2개
다른 form으로도 만들어줘
단어: ( \(word) )
"""
    }
}
