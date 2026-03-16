//
//  SentenceLemmas.swift
//  LessonClient
//
//  Created by ym on 3/16/26.
//

import Foundation

extension Prompt {
    static func makeLemmaPrompt(for text: String) -> String {
        """
입력한 영어단어 목록에서 lemma만 추출해서 출력

구두점, 번호, 설명은 빼고 lemma만 쉼표로 나열해줘
숙어/구문이면 필요한 공백은 유지해줘

lemma,lemma, ...

word: \(text)
"""
    }
}
