//
//  SensePrompts.swift
//  LessonClient
//
//  Created by 정영민 on 3/8/26.
//

import Foundation

struct Prompt {
}

extension Prompt {
    static func makeSentenceTokenSensePrompt(copyText: String) -> String {
        """
입력한 tokens들이 문장에서 해당되는 senseid를 출력
내용에 해당되는 sense_id없으면 비워줘 (the, on, get, in, make, take, have, so, a, to는 가장 비슷한것 찾아줘)
다른 설명 없이 아래 출력방식만 반복해서 출력

출력방식
token:
token_id:
sense_id:

\(copyText)
"""
    }
}
