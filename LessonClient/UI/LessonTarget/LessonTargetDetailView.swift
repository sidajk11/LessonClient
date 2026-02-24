//
//  LessonTargetDetailView.swift
//  LessonClient
//
//  Created by ym on 2/24/26.
//

import SwiftUI

struct LessonTargetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: LessonTargetDetailViewModel
    @State private var showDeleteConfirm: Bool = false

    init(targetId: Int) {
        _vm = StateObject(wrappedValue: LessonTargetDetailViewModel(targetId: targetId))
    }

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("lesson_id", text: $vm.lessonIdText)
                TextField("target_type", text: $vm.targetType)
                TextField("word_id", text: $vm.wordIdText)
                TextField("form_id", text: $vm.formIdText)
                TextField("sense_id", text: $vm.senseIdText)
                TextField("display_text", text: $vm.displayText)
                TextField("sort_index", text: $vm.sortIndexText)
            }

            if let item = vm.item {
                Section("읽기 전용") {
                    HStack {
                        Text("id")
                        Spacer()
                        Text(String(item.id)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("created_at")
                        Spacer()
                        Text(dateText(item.createdAt)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("last_reviewed_at")
                        Spacer()
                        Text(dateText(item.lastReviewedAt)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("next_review_at")
                        Spacer()
                        Text(dateText(item.nextReviewAt)).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Button {
                        Task { await vm.save() }
                    } label: {
                        if vm.isSaving { ProgressView() } else { Text("저장") }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if vm.isDeleting { ProgressView() } else { Text("삭제") }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("LessonTarget #\(vm.targetId)")
        .frame(minWidth: 460, minHeight: 520)
        .task { await vm.load() }
        .alert("오류", isPresented: .constant(vm.errorMessage != nil)) {
            Button("확인") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("완료", isPresented: .constant(vm.infoMessage != nil)) {
            Button("확인") { vm.infoMessage = nil }
        } message: {
            Text(vm.infoMessage ?? "")
        }
        .confirmationDialog("LessonTarget를 삭제할까요?", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                Task {
                    let deleted = await vm.delete()
                    if deleted { dismiss() }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func dateText(_ value: Date?) -> String {
        guard let value else { return "-" }
        return Self.dateFormatter.string(from: value)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
