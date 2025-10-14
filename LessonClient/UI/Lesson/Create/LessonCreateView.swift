//
//  LessonCreateView.swift
//  LessonClient
//
//  Created by 정영민 on 8/31/25.
//  MVVM refactor on 10/13/25
//

import SwiftUI

struct LessonCreateView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: ((Lesson) -> Void)? = nil

    @StateObject private var vm = LessonCreateViewModel()

    var body: some View {
        Form {
            Section("기본 정보") {
                Stepper("Unit: \(vm.unit)", value: $vm.unit, in: 1...100)
                Stepper("레벨: \(vm.level)", value: $vm.level, in: 1...100)
                TextField("토픽", text: $vm.topic)
                TextField("문법", text: $vm.grammar)
            }

            if let e = vm.error {
                Text(e).foregroundColor(.red)
            }

            Button {
                Task {
                    do {
                        let newLesson = try await vm.createLesson()
                        onCreated?(newLesson)
                        dismiss()
                    } catch {
                        vm.error = (error as NSError).localizedDescription
                    }
                }
            } label: {
                if vm.isSaving { ProgressView() } else { Text("저장") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canSave)
        }
        .navigationTitle("새 레슨")
        .frame(minWidth: 420)
    }
}
