//
//  VocabularyDetailView.swift
//  LessonClient
//
//  Created by ymj on 10/13/25.
//  UI updated to use bulk translation text editors for examples
//

import SwiftUI

struct VocabularyDetailView: View {
    @StateObject private var vm: VocabularyDetailViewModel

    init(wordId: Int, lesson: Lesson?) {
        _vm = StateObject(wrappedValue: VocabularyDetailViewModel(wordId: wordId, lesson: lesson))
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
        .sheet(isPresented: $vm.isExampleAttachmentPresented) {
            NavigationStack {
                VocabularyExampleAttachmentSheet(viewModel: vm)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        if let e = vm.word {
            Section("단어") {
                TextField("기본 텍스트 (Vocabulary.text)", text: Binding(
                    get: { e.text },
                    set: { vm.word?.text = $0 }
                ))

                Toggle(
                    "exampleExercise",
                    isOn: Binding(
                        get: { vm.word?.exampleExercise ?? true },
                        set: { vm.word?.exampleExercise = $0 }
                    )
                )

                Toggle(
                    "vocabularyExercise",
                    isOn: Binding(
                        get: { vm.word?.vocabularyExercise ?? true },
                        set: { vm.word?.vocabularyExercise = $0 }
                    )
                )

                Toggle(
                    "isForm",
                    isOn: Binding(
                        get: { vm.word?.isForm ?? true },
                        set: { vm.word?.isForm = $0 }
                    )
                )

                HStack {
                    Button("기본 텍스트 저장") { Task { await vm.saveVocabulary() } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button(role: .destructive) { Task { await vm.removeVocabulary() } } label: {
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
            metadataSection(for: e)
            senseListSection
            formListSection
            
            // + 새 예문 추가 네비게이션 (필요 시 유지)
            NavigationLink {
                ExampleSentenceCreateView(wordId: vm.wordId) { _ in
                    Task { await vm.load() }
                }
            } label: {
                Label("새 예문 추가", systemImage: "plus.circle")
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
            Button {
                vm.presentExampleAttachment()
            } label: {
                Label("예문 검색·연결", systemImage: "link.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.word == nil)

            if vm.examples.isEmpty {
                Text("예문이 없습니다. 아래에서 예문을 추가해 보세요.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(vm.examples) { example in
                        HStack {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // example에 속한 모든 ExampleSentence를 가로로 나열합니다.
                                    ForEach(example.orderedExampleSentences) { exampleSentence in
                                        NavigationLink {
                                            ExampleSentenceDetailView(exampleSentence: exampleSentence, lesson: vm.lesson, word: vm.word)
                                        } label: {
                                            Text(exampleSentence.text)
                                                .lineLimit(1)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.secondary.opacity(0.08))
                                                )
                                        }
                                        .buttonStyle(.plain) // macOS에서 과한 버튼 스타일 제거
                                    }
                                }
                            }

                            Spacer()

                            // 항상 보이는 detach 버튼
                            Button {
                                Task { await vm.detachExample(example.id) }
                            } label: {
                                Label("detatch", systemImage: "link.badge.minus")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
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

    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func metadataSection(for word: Vocabulary) -> some View {
        Section("메타데이터") {
            TextField("sense_id", text: $vm.senseIdText)
                .textFieldStyle(.roundedBorder)
                .disabled(vm.isUpdatingSense)

            Button("sense_id 적용") {
                Task { await vm.applySenseId() }
            }
            .buttonStyle(.bordered)
            .disabled(vm.isUpdatingSense)

            HStack {
                Text("sense_code")
                Spacer()
                Button(vm.senseCodeText) {
                    Task { await vm.toggleSenseList() }
                }
                .buttonStyle(.link)
                .disabled(!vm.canChangeSense)
            }

            metadataRow(title: "form_id", value: word.formId.map(String.init) ?? "-")
            HStack {
                Text("form")
                Spacer()
                Button(vm.formText) {
                    Task { await vm.toggleFormList() }
                }
                .buttonStyle(.link)
                .disabled(!vm.canChangeForm)

                if word.formId != nil {
                    Button("해제") {
                        Task { await vm.clearForm() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(vm.isUpdatingForm)
                }
            }
            metadataRow(title: "phrase_id", value: word.phraseId.map(String.init) ?? "-")
        }
    }

    @ViewBuilder
    private var senseListSection: some View {
        if vm.isSenseListExpanded {
            Section("Sense 리스트") {
                if vm.availableSenses.isEmpty {
                    Text("선택 가능한 sense가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.availableSenses) { sense in
                        senseRow(sense)
                    }

                    if vm.isUpdatingSense {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var formListSection: some View {
        if vm.isFormListExpanded {
            Section("Form 리스트") {
                if vm.availableForms.isEmpty {
                    Text("선택 가능한 form이 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.availableForms) { form in
                        formRow(form)
                    }

                    if vm.isUpdatingForm {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func senseRow(_ sense: WordSenseRead) -> some View {
        Button {
            Task { await vm.updateSense(to: sense) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: vm.word?.senseId == sense.id ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(vm.word?.senseId == sense.id ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("sense_id: \(sense.id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(sense.senseCode)
                            .font(.headline)
                    }

                    Text(vm.koreanText(for: sense))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(vm.isUpdatingSense)
    }

    private func formRow(_ form: WordFormRead) -> some View {
        Button {
            Task { await vm.updateForm(to: form) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: vm.word?.formId == form.id ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(vm.word?.formId == form.id ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("form_id: \(form.id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(form.form)
                            .font(.headline)
                    }

                    Text(form.formType ?? "-")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(vm.koreanText(for: form))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(vm.isUpdatingForm)
    }
}

private struct VocabularyExampleAttachmentSheet: View {
    @ObservedObject var viewModel: VocabularyDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("이 학습단어에 연결할 예문을 검색하세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("이미 다른 학습단어에 직접 연결된 예문을 선택하면 연결 대상이 이 단어로 변경됩니다.")
                .font(.footnote)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                TextField("예문 또는 번역 검색", text: $viewModel.exampleSearchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.searchExamplesForAttachment() }
                    }

                Button("검색") {
                    Task { await viewModel.searchExamplesForAttachment() }
                }
                .disabled(viewModel.isSearchingExamples)
            }

            if let error = viewModel.exampleAttachmentErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.isSearchingExamples {
                ProgressView("예문 검색 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.exampleSearchResults.isEmpty {
                ContentUnavailableView(
                    "연결할 예문이 없습니다",
                    systemImage: "text.magnifyingglass",
                    description: Text("검색어를 바꾸어 다시 검색해 보세요.")
                )
            } else {
                List(viewModel.exampleSearchResults) { example in
                    VocabularyExampleAttachmentResultRow(
                        example: example,
                        isAttaching: viewModel.isAttachingExample(id: example.id),
                        onAttach: {
                            Task { await viewModel.attachExample(example) }
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .frame(minWidth: 680, minHeight: 480)
        .navigationTitle("예문 연결")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("닫기") { dismiss() }
            }
        }
    }
}

private struct VocabularyExampleAttachmentResultRow: View {
    let example: Example
    let isAttaching: Bool
    let onAttach: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(example.firstExampleSentence?.text ?? "문장이 없는 예문")
                    .font(.body)
                    .lineLimit(2)

                if let sentence = example.firstExampleSentence {
                    let translation = sentence.translations.toString()
                    if !translation.isEmpty {
                        Text(translation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Text("예문 #\(example.id) · 연결 단어: \(example.wordText ?? "-")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onAttach()
            } label: {
                if isAttaching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("연결")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAttaching)
        }
        .padding(.vertical, 4)
    }
}
