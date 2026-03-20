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
영어 단어 lemma의 메인 sense들을 출력해줘.
example은 반드시 해당 CEFR 레벨 문장만 사용

pos
CEFR 레벨 (cambridge 사전이랑 동일)
번역
example
출력 형식:  (출력형식에 맞게 출력 부가 설명은 하지 말아줘, word:는 lemma만 출력)
word:
sense: 
pos: 
cefr:
ko: 
example:

word: \(word)
"""
    }
}
