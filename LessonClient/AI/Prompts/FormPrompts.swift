//
//  FormPrompts.swift
//  LessonClient
//
//  Created by 정영민 on 3/8/26.
//

import Foundation

extension Prompt {
    static func makeFormPrompt(for word: String) -> String {
        """
입력한 단어의 lemma를 만들고 lemma의 활용형(form)들을 출력해줘. 
구문은 분리하지 말고 구문으로만 form을 찾아줘.

form_type은 (base, past, past_participle, present_participle, 3sg, plural, comparative, superlative 중에서만 선택)

출력 형식에 맞게 출력해줘
word: <단어>
form: <활용형>
form_type: <형태 유형>

단어: ( \(word) )
"""
    }
}
