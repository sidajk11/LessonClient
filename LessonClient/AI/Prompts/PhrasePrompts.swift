//
//  PhrasePrompts.swift
//  LessonClient
//
//  Created by ym on 3/17/26.
//

import Foundation

extension Prompt {
    func makePhrasePrompts(phrase: String) -> String {
        """
        phrase를 번역해줘 
        출력방식
        phrase: 
        ko: 
        
        phrase: \(phrase)
        """
    }
}
