//
//  LessonDetailView.swift
//  LessonClient
//
//  Created by ymj on 9/22/25.
//  MVVM refactor on 10/13/25
//

import SwiftUI

struct LessonDetailView: View {
    let lessonId: Int
    @StateObject private var vm: LessonDetailViewModel
    @State private var showDeleteAlert: Bool = false
    var onDismiss: (() -> Void)? = nil

    init(lessonId: Int, onDismiss: (() -> Void)? = nil) {
        self.lessonId = lessonId
        self.onDismiss = onDismiss
        _vm = StateObject(wrappedValue: LessonDetailViewModel(lessonId: lessonId))
    }

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("Unit:", text: $vm.unitText)
                TextField("토픽", text: $vm.topic)
                TextField("문법", text: $vm.grammar)

                HStack {
                    Button("수정 저장") { Task { await vm.save() } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Text("레슨 삭제")
                    }
                }
            }

            NavigationLink("+ 새 단어 만들기") {
                VocabularyCreateView(onCreated: { words in
                    for word in words {
                        Task { await vm.attach(word.id) }
                    }
                })
            }

            if !vm.exerciseRows.isEmpty {
                List {
                    Section("Exercises (\(vm.exerciseRows.count))") {
                        ForEach(vm.exerciseRows) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(row.title)
                                        .bold()
                                    Spacer()
                                    Text(row.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let prompt = row.prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !prompt.isEmpty,
                                   prompt != row.title {
                                    Text(prompt)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 160)
            }

            List {
                Section("Vocabularies (\(vm.vocabularyRows.count))") {
                    if vm.isLoadingVocabularies {
                        ProgressView()
                    }

                    if vm.vocabularyRows.isEmpty {
                        Text("연결된 단어가 없습니다.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.vocabularyRows) { row in
                        HStack(spacing: 8) {
                            NavigationLink {
                                VocabularyDetailView(wordId: row.id, lesson: vm.model)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.text)

                                    if !row.translations.isEmpty {
                                        Text(row.translations.toString())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()
                            Button("해제") {
                                Task { await vm.detach(row.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 220)

            Section("단어 검색 & 연결") {
                HStack {
                    TextField("검색", text: $vm.wq)
                        .onSubmit { Task { await vm.doVocabularySearch() } }
                    Button("검색") { Task { await vm.doVocabularySearch() } }
                }

                ForEach(vm.wsearch, id: \.id) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(w.text).bold()
                            if !w.translations.isEmpty {
                                let langs = w.translations.map { $0.langCode.rawValue }.joined(separator: ", ")
                                Text("[\(langs)]")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("번역 없음")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("연결") { Task { await vm.attach(w.id) } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("레슨 상세")
        .task { await vm.load() }
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .alert("레슨 삭제?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) { Task { await vm.remove() } }
            Button("취소", role: .cancel) { }
        }
        .onDisappear {
            onDismiss?()
        }
    }
}
