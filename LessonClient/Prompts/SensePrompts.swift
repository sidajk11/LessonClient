//
//  SensePrompts.swift
//  LessonClient
//
//  Created by ym on 3/9/26.
//

import Foundation

extension Prompt {
    static func makeSensePrompt(for word: String) -> String {
        """
영어 단어의 모든 sense들을 빠짐없이 출력하줘.


pos
CEFR 레벨 (cambridge 사전이랑 동일)
번역
example

출력 형식:  (출력형식에 맞게 출력 부가 설명은 하지 말아줘)
word:
sense: 
pos: 
cefr:
ko: 
example: 

\(word)
"""
    }
}
