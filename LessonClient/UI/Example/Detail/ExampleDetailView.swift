// ExampleDetailView.swift

import SwiftUI

struct ExampleDetailView: View {
    @StateObject private var vm: ExampleDetailViewModel

    init(exampleId: Int) {
        _vm = StateObject(wrappedValue: ExampleDetailViewModel(exampleId: exampleId))
    }

    var body: some View {
        Form {
            Section(header: Text("연습문제")) {
                NavigationLink("연습문제들") {
                    if let example = vm.example {
                        ExerciseListView(example: example)
                    }
                }
            }
            Section("문장") {
                TextField("영어 문장", text: $vm.sentence)
                    .autocorrectionDisabled()
            }
            Section("번역들") {
                Text("한 줄에 하나씩 입력하세요.\n예)\nko: 내 가방과 내 휴대폰.\nes: Mi bolsa y mi teléfono.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $vm.translationText)
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }

            Button {
                Task { await vm.save() }
            } label: {
                if vm.isSaving { ProgressView() } else { Text("저장") }
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("예문 상세")
        .task { await vm.load() }
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .alert("완료", isPresented: .constant(vm.info != nil)) {
            Button("확인") { vm.info = nil }
        } message: { Text(vm.info ?? "") }
    }
}
