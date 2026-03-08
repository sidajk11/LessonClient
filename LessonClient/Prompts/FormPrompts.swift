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
사용자가 영어 단어를 입력하면, 그 단어의 모든 활용형(form)과 각 형태의 유형(form_type), 한국어 설명(explain_ko)을 출력합니다. 

singular은 출력하지마
없으면 출력하지마

출력 형식에 맞게 출력해줘

word: <단어>
form: <활용형>
form_type: <형태 유형>
explain_ko: <한국어 설명>

사용자가 입력한 단어에 맞는 모든 form과 form_type, 한국어 설명을 위 형식으로 나열하세요.

\(word)
"""
    }
}
