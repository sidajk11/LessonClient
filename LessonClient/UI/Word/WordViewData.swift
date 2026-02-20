//
//  Word.swift
//  LessonClient
//
//  Created by ym on 2/19/26.
//

import SwiftUI

struct WordViewData {
    struct Sense {
        let id: UUID = UUID()
        let senseCode: String
        let tr1: String
        let tr2: String
        let pos: String
        let explain: String
    }
}
