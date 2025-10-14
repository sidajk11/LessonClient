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

    init(lessonId: Int) {
        self.lessonId = lessonId
        _vm = StateObject(wrappedValue: LessonDetailViewModel(lessonId: lessonId))
    }

    var body: some View {
        Form {
            // MARK: 기본 정보
            Section("기본 정보") {
                Stepper("Unit: \(vm.unit)", value: $vm.unit, in: 1...100)
                Stepper("레벨: \(vm.level)", value: $vm.level, in: 1...100)
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

            // MARK: 단어 목록
            List {
                Section("단어 (\(vm.words.count))") {
                    ForEach(vm.words, id: \.id) { w in
                        NavigationLink {
                            WordDetailView(wordId: w.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(w.text).bold()

                                    if !w.translations.isEmpty {
                                        let langs = w.translations.map { $0.langCode }.joined(separator: ", ")
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
            .frame(minHeight: 300)

            // MARK: 단어 검색 & 연결
            Section("단어 검색 & 연결") {
                HStack {
                    TextField("검색", text: $vm.wq)
                        .onSubmit { Task { await vm.doWordSearch() } }
                    Button("검색") { Task { await vm.doWordSearch() } }
                }

                ForEach(vm.wsearch, id: \.id) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(w.text).bold()
                            if !w.translations.isEmpty {
                                let langs = w.translations.map { $0.langCode }.joined(separator: ", ")
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

                NavigationLink("+ 새 단어 만들기") {
                    WordCreateView(onCreated: { w in
                        Task { await vm.attach(w.id) }
                    })
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
    }
}
