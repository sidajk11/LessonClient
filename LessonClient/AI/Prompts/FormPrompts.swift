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
입력한 단어의 lemma를 만들고 lemma의 활용형(form)을 출력해줘. 

없으면 출력하지마

출력 형식에 맞게 출력해줘

word: <단어>
form: <활용형>
form_type: <형태 유형>

\(word)
"""
    }
}
