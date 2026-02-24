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
    @State private var sensePickerRow: LessonTargetRow?
    var onDismiss: (() -> Void)? = nil

    init(lessonId: Int, onDismiss: (() -> Void)? = nil) {
        self.lessonId = lessonId
        self.onDismiss = onDismiss
        _vm = StateObject(wrappedValue: LessonDetailViewModel(lessonId: lessonId))
    }

    var body: some View {
        Form {
            // MARK: 기본 정보
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

            // MARK: 단어 목록
            List {
                Section("단어 (\(vm.vocabularys.count))") {
                    ForEach(vm.vocabularys, id: \.id) { w in
                        NavigationLink {
                            VocabularyDetailView(wordId: w.id, lesson: vm.model)
                        } label: {
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
                                Button("제거") { Task { await vm.detach(w.id) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 220)

            // MARK: Word 목록
            List {
                Section("Words (\(vm.wordRows.count))") {
                    if vm.isLoadingWordRows {
                        ProgressView()
                    }

                    if vm.wordRows.isEmpty && !vm.vocabularys.isEmpty {
                        Button {
                            Task { await vm.createLessonTargetsFromVocabularies() }
                        } label: {
                            if vm.isCreatingLessonTargets {
                                ProgressView()
                            } else {
                                Text("LessonTargets 생성")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    ForEach(vm.wordRows) { row in
                        HStack(spacing: 8) {
                            NavigationLink {
                                if let phraseId = row.phraseId {
                                    PhraseDetailView(phraseId: phraseId)
                                } else {
                                    LessonTargetDetailView(targetId: row.id)
                                }
                            } label: {
                                Text(row.wordDisplayText)
                            }
                            .buttonStyle(.plain)

                            Spacer()
                            Button(row.selectedSenseCode) {
                                sensePickerRow = row
                            }
                            .buttonStyle(.bordered)
                            .disabled(row.senses.isEmpty)

                            Spacer()
                            Text(row.translation)

                            Spacer()
                            Text(row.formId.map(String.init) ?? "-")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 220)

            // MARK: 단어 검색 & 연결
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
        .sheet(item: $sensePickerRow) { row in
            NavigationStack {
                List {
                    if let currentRow = vm.wordRows.first(where: { $0.id == row.id }) {
                        ForEach(currentRow.senses) { sense in
                            Button {
                                vm.selectSense(wordRowId: row.id, senseId: sense.id)
                                sensePickerRow = nil
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sense.senseCode).bold()
                                    Text(sense.translations.first(where: { $0.lang.lowercased() == "ko" })?.text ?? "-")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(sense.examples.first?.sentence ?? "")
                                }
                            }
                        }
                    } else {
                        Text("No senses")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 420, minHeight: 320)
                .navigationTitle("WordSenseList")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("닫기") { sensePickerRow = nil }
                    }
                }
            }
            .frame(minWidth: 420, minHeight: 360)
        }
        .onDisappear {
            onDismiss?()
        }
    }
}
