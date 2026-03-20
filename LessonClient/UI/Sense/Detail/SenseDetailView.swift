//
//  SenseDetailView.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import SwiftUI

struct SenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: SenseDetailViewModel
    @State private var showDeleteConfirm: Bool = false

    init(senseId: Int) {
        _vm = StateObject(wrappedValue: SenseDetailViewModel(senseId: senseId))
    }

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("senseCode", text: $vm.senseCode)

                TextField("품사 (pos)", text: $vm.pos)

                TextField("CEFR", text: $vm.cefr)

                VStack(alignment: .leading, spacing: 6) {
                    Text("설명")
                        .font(.subheadline)
                    TextEditor(text: $vm.explain)
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                }
            }

            Section("번역") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("텍스트")
                        .font(.subheadline)
                    TextEditor(text: $vm.translationsText)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("언어별 설명")
                        .font(.subheadline)
                    TextEditor(text: $vm.translationExplainsText)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                }

                Text("형식: `ko: 번역문` 처럼 한 줄에 하나씩 입력합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let sense = vm.sense {
                Section("읽기 전용") {
                    detailRow(title: "senseId", value: String(sense.id))
                    detailRow(title: "wordId", value: String(sense.wordId))
                    detailRow(title: "isPrimary", value: sense.isPrimary ? "true" : "false")

                    if let word = vm.word {
                        NavigationLink {
                            WordDetailView(wordId: word.id)
                        } label: {
                            HStack {
                                Text("word")
                                Spacer()
                                Text(word.lemma)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("예문") {
                if vm.examples.isEmpty {
                    Text("연결된 예문이 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.examples) { example in
                        NavigationLink {
                            ExampleDetailView(exampleId: example.id, lesson: nil, word: nil)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(example.sentence)
                                if !example.translations.isEmpty {
                                    Text(example.translations.toString())
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button {
                        Task { await vm.save() }
                    } label: {
                        if vm.isSaving {
                            ProgressView()
                        } else {
                            Text("저장")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isSaveDisabled)

                    Spacer()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if vm.isDeleting {
                            ProgressView()
                        } else {
                            Text("삭제")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isDeleting)
                }
            }
        }
        .navigationTitle("Sense #\(vm.senseId)")
        .frame(minWidth: 520, minHeight: 760)
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
        .confirmationDialog("Sense를 삭제할까요?", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                Task {
                    let deleted = await vm.delete()
                    if deleted {
                        dismiss()
                    }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
