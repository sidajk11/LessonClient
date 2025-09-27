//
//  LessonEditScreen.swift
//  LessonClient
//
//  Created by 정영민 on 8/31/25.
//

// LessonEditScreen.swift (새 파일)
import SwiftUI

struct LessonEditScreen: View {
    @Environment(\.dismiss) private var dismiss
    // 생성이 끝났을 때 목록에 즉시 반영하려면 콜백을 받아옵니다.
    var onCreated: ((Lesson) -> Void)? = nil

   //@State private var name = ""
    @State private var unit = 1
    @State private var level = 1
    @State private var topic = ""
    @State private var grammar = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("기본 정보") {
                //TextField("레슨 이름", text: $name)
                Stepper("레벨: \(unit)", value: $unit, in: 1...100)
                Stepper("레벨: \(level)", value: $level, in: 1...100)
                TextField("토픽", text: $topic)
                TextField("문법", text: $grammar)
            }

            if let e = error { Text(e).foregroundColor(.red) }

            Button(saving ? "저장 중…" : "저장") {
                Task { await save() }
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("새 레슨")
        .frame(minWidth: 420)
    }

    private func save() async {
        saving = true
        do {
            let newLesson = try await APIClient.shared.createLesson(
                name: "",
                unit: unit,
                level: level,
                topic: topic.isEmpty ? nil : topic,
                grammar: grammar.isEmpty ? nil : grammar
            )
            onCreated?(newLesson)
            dismiss()
        } catch let err {
            self.error = err.localizedDescription
        }
        saving = false
    }
}
