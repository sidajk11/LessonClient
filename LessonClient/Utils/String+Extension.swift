//
//  String+Extension.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//

extension String {
    var int: Int? {
        Int(self)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Substring {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
