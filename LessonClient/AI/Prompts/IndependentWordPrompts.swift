//
//  IndependentWordPrompts.swift
//  LessonClient
//
//  Created by ym on 4/3/26.
//

import Foundation

extension Prompt {
    static func makeIndependentWordPrompts(for word: String) -> String {
        """
영어단어 형태는 form에서 왔지만 독립된 단어로 학습하는 것이 필요한지 판단해줘.

문법 형태로 이해하면 충분하면 필요없고
의미가 굳어진 단어이고 자주 쓰이는 표현이 따로 있으면 필요

Y/N으로  답해줘 

단어: ( \(word) )
"""
    }
}
