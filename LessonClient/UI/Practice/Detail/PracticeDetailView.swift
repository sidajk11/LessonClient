//
//  PracticeDetailView.swift
//  LessonClient
//
//  Created by ymj on 10/21/25.
//

import SwiftUI

struct PracticeDetailView: View {
    @StateObject private var vm: PracticeDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var onDeleted: (() -> Void)?

    init(example: Example, practice: Practice,
         onDeleted: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: PracticeDetailViewModel(example: example, practice: practice))
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
                infoRow(title: "ID", value: "#\(vm.practice.id)")
                infoRow(title: "유형", value: vm.practice.type.rawValue)
            }

            Section("문장") {
                Text(vm.sentence)
                    .font(.body)
                    .textSelection(.enabled)
            }

            Section("내용") {
                Text(vm.content)
                    .font(.body)
                    .textSelection(.enabled)
            }

            Section("단어") {
                Text(vm.optionsText)
                    .font(.body)
                    .textSelection(.enabled)
            }

            // ✅ select 타입일 때: 더미 단어 관리 UI
            if vm.practice.type == .select {
                Section("더미 단어 관리") {
                    if vm.isLoadingVocabularys {
                        ProgressView("불러오는 중…")
                    } else {
                        // 현재 보기(토글로 제거 가능)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("현재 보기")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            let cols = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                            LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                                ForEach(vm.currentOptions, id: \.self) { w in
                                    Button {
                                        vm.toggle(word: w)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text(w)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("‘\(w)’ 제거")
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        // 추가 가능한 단어(토글로 추가 가능)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("추가 가능")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            let cols = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                            LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                                ForEach(vm.extraVocabularys, id: \.self) { w in
                                    Button {
                                        vm.toggle(word: w)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(w)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.clear))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.35), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("‘\(w)’ 추가")
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        // 저장 버튼
                        Button {
                            Task { await vm.saveOptions() }
                        } label: {
                            if vm.isSaving {
                                ProgressView()
                            } else {
                                Text("변경사항 저장").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isSaving || !vm.hasChanges)
                    }
                }
            }
        }
        .navigationTitle("연습문제 #\(vm.practice.id)")
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

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}


