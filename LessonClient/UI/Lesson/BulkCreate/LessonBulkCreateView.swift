//
//  LessonBulkCreateView.swift
//  LessonClient
//
//  Created by Codex on 3/17/26.
//

import SwiftUI

struct LessonBulkCreateView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: (([Lesson]) -> Void)? = nil

    @StateObject private var vm = LessonBulkCreateViewModel()

    var body: some View {
        Form {
            Section("레슨 정보") {
                TextField("토픽", text: $vm.topic)

                HStack {
                    TextField("Unit", text: $vm.unitText)
                        .onChange(of: vm.unitText) { _, newValue in
                            vm.unitText = newValue.filter(\.isNumber)
                        }

                    if vm.isLoadingDefaultUnit {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            Section("단어 리스트") {
                TextEditor(text: $vm.wordListText)
                    .font(.body)
                    .frame(minHeight: 180)

                Text("쉼표(,) 또는 줄바꿈으로 구분합니다. 예: like to, love to, photography, ballet")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("총 \(vm.parsedWords.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("생성될 레슨 \(vm.lessonCount)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = vm.error {
                Text(error)
                    .foregroundColor(.red)
            }

            Button {
                Task {
                    do {
                        let lessons = try await vm.bulkCreate()
                        onCreated?(lessons)
                        dismiss()
                    } catch {
                        vm.error = (error as NSError).localizedDescription
                    }
                }
            } label: {
                if vm.isSaving {
                    ProgressView()
                } else {
                    Text("저장")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canSave)
        }
        .navigationTitle("레슨 일괄추가")
        .frame(minWidth: 480, minHeight: 420)
    }
}
