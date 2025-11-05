//
//  WordDetailView.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//  UI updated to use bulk translation text editors for examples
//

import SwiftUI

struct WordDetailView: View {
    @StateObject private var vm: WordDetailViewModel

    init(wordId: Int, lesson: Lesson?) {
        _vm = StateObject(wrappedValue: WordDetailViewModel(wordId: wordId, lesson: lesson))
    }

    var body: some View {
        Form {
            headerSection
            examplesSection
        }
        .navigationTitle(vm.word?.text ?? "단어")
        .task { await vm.load() }
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .alert("완료", isPresented: .constant(vm.info != nil)) {
            Button("확인") { vm.info = nil }
        } message: { Text(vm.info ?? "") }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        if let e = vm.word {
            Section("단어") {
                TextField("기본 텍스트 (Word.text)", text: Binding(
                    get: { e.text },
                    set: { vm.word?.text = $0 }
                ))

                HStack {
                    Button("기본 텍스트 저장") { Task { await vm.saveWord() } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button(role: .destructive) { Task { await vm.removeWord() } } label: {
                        Text("단어 삭제")
                    }
                }
            }

            Section("레슨") {
                HStack {
                    TextField("Unit", text: $vm.unitText)
                    Button("연결") { Task { await vm.attachToLesson() } }
                }
            }
            
            Section("번역들") {
                TextEditor(text: $vm.translationText)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Text("예)\nko: 나의 / 내\nes: mi")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
        } else {
            Section { ProgressView().frame(maxWidth: .infinity) }
        }
    }

    @ViewBuilder
    private var examplesSection: some View {
        Section("예문") {
            if vm.examples.isEmpty {
                Text("예문이 없습니다. 아래에서 예문을 추가해 보세요.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(vm.examples) { example in
                        HStack {
                            // 상세로 이동
                            NavigationLink {
                                ExampleDetailView(exampleId: example.id, lesson: vm.lesson, word: vm.word)
                            } label: {
                                Text(example.text)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain) // macOS에서 과한 버튼 스타일 제거

                            Spacer()

                            // 항상 보이는 삭제 버튼
                            Button(role: .destructive) {
                                Task { await vm.deleteExample(example.id) }
                            } label: {
                                Label("삭제", systemImage: "trash")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // + 새 예문 추가 네비게이션 (필요 시 유지)
            NavigationLink {
                ExampleCreateView(wordId: vm.wordId) { examples in
                    vm.examples.insert(contentsOf: examples, at: 0)
                }
            } label: {
                Label("새 예문 추가", systemImage: "plus.circle")
            }
        }
    }



    @ViewBuilder
    private var addExampleSection: some View {
        Section("예문 추가") {
            TextField("영어 문장", text: $vm.newSentence)
                .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: 6) {
                Text("번역들 (한 줄에 하나)\n예)\nko: 내 가방과 내 휴대폰.\nes: Mi bolsa y mi teléfono.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $vm.newSentencetranslationText)
                    .frame(minHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }

            HStack {
                Spacer()
                Button("예문 생성") { Task { await vm.addExample() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isCreateDisabled)
            }
        }
    }
}

