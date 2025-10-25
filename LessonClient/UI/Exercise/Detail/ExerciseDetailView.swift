//
//  ExerciseDetailView.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import SwiftUI

struct ExerciseDetailView: View {
    @StateObject private var vm: ExerciseDetailViewModel
    @Environment(\.dismiss) private var dismiss

    /// 삭제 완료 시 상위에서 새로고침하도록 콜백
    var onDeleted: (() -> Void)?

    init(exercise: Exercise,
         onDeleted: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: ExerciseDetailViewModel(exercise: exercise))
        self.onDeleted = onDeleted
    }

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section("오류") {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("기본 정보") {
                infoRow(title: "ID", value: "#\(vm.exercise.id)")
                infoRow(title: "유형", value: vm.exercise.type)
            }
            
            Section("내용") {
                Text(vm.exercise.translations.first(where: { $0.langCode == .ko })?.content ?? "")
                    .font(.body)
                    .textSelection(.enabled)
            }

            Section("단어") {
                Text(vm.exercise.wordOptions.enText())
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("연습문제 #\(vm.exercise.id)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    vm.showDeleteConfirm = true
                } label: {
                    if vm.isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .help("연습문제 삭제")
                .disabled(vm.isDeleting)
            }
        }
        .confirmationDialog(
            "정말 삭제할까요?",
            isPresented: $vm.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task {
                    let ok = await vm.delete()
                    if ok {
                        onDeleted?()
                        dismiss()
                    }
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("이 작업은 되돌릴 수 없습니다.")
        }
    }

    // MARK: - UI helpers
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

