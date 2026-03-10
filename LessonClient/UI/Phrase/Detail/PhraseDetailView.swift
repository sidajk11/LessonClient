//
//  PhraseDetailView.swift
//  LessonClient
//
//  Created by ym on 2/24/26.
//

import SwiftUI

struct PhraseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: PhraseDetailViewModel
    @State private var showDeleteConfirm: Bool = false

    init(phraseId: Int) {
        _vm = StateObject(wrappedValue: PhraseDetailViewModel(phraseId: phraseId))
    }

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("text", text: $vm.text)
            }

            Section("translations") {
                TextEditor(text: $vm.translationsText)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Text("예)\nko: 문구 번역\nja: フレーズ訳")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let phrase = vm.phrase {
                Section("읽기 전용") {
                    HStack {
                        Text("id")
                        Spacer()
                        Text(String(phrase.id)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("normalized")
                        Spacer()
                        Text(phrase.normalized).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("created_at")
                        Spacer()
                        Text(phrase.createdAt ?? "-").foregroundStyle(.secondary)
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
        .navigationTitle("Phrase #\(vm.phraseId)")
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
        .confirmationDialog("Phrase를 삭제할까요?", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                Task {
                    let deleted = await vm.delete()
                    if deleted { dismiss() }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }
}
