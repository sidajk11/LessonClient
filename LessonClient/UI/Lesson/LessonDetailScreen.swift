//
//  LessonDetailScreen.swift
//  LessonClient
//
//  Created by ymj on 9/22/25.
//

import SwiftUI

struct LessonDetailScreen: View {
    let lessonId: Int
    @State private var model: Lesson?
    @State private var name = ""
    @State private var unit = 1
    @State private var level = 1
    @State private var topic = ""
    @State private var grammar = ""
    @State private var q = ""
    @State private var search: [Word] = []
    // ▼▼▼ expressions용 상태 추가 ▼▼▼
    @State private var eq = ""
    @State private var esearch: [Expression] = []
    // ▲▲▲ expressions용 상태 추가 ▲▲▲
    @State private var error: String?
    
    @State private var exprs: [Expression] = []
    
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        Form {
            // 기존 섹션 ...
            Section("기본 정보") {
                TextField("이름", text: $name)
                Stepper("Unit: \(unit)", value: $level, in: 1...100)
                Stepper("레벨: \(level)", value: $level, in: 1...100)
                TextField("토픽", text: $topic)
                TextField("문법", text: $grammar)
                Button("수정 저장") { Task { await save() } }
                Button(role: .destructive, action: { showDeleteAlert = true }) { Text("레슨 삭제") }
            }

//            // 단어 섹션 (기존)
//            if let words = model?.words {
//                Section("단어 (\(words.count))") {
//                    ForEach(words, id: \.id) { w in
//                        HStack {
//                            Text(w.text)
//                            Spacer()
//                            Button("제거") { Task { await detach(w.id) } }
//                        }
//                    }
//                }
//            }
//
//            // 단어 검색/연결 (기존)
//            Section("단어 검색 & 연결") {
//                HStack {
//                    TextField("검색", text: $q).onSubmit { Task { await doSearch() } }
//                    Button("검색") { Task { await doSearch() } }
//                }
//                ForEach(search, id: \.id) { w in
//                    HStack {
//                        VStack(alignment: .leading) {
//                            Text(w.text).bold()
//                            Text(w.meanings.joined(separator: ", ")).foregroundStyle(.secondary)
//                        }
//                        Spacer()
//                        Button("연결") { Task { await attach(w.id) } }
//                    }
//                }
//                NavigationLink("+ 새 단어 만들기") {
//                    WordEditScreen(onCreated: { w in
//                        Task { await attach(w.id) }
//                    })
//                }
//            }
            
            List {
                Section("표현 (\(exprs.count))") {
                    ForEach(exprs, id: \.id) { e in
                        NavigationLink {
                            ExpressionDetailScreen(expressionId: e.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(e.text).bold()
                                    let m = e.meanings
                                    if !m.isEmpty {
                                        Text(m.joined(separator: ", ")).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button("제거") { Task { await detachExpression(e.id) } }
                            }
                        }
                    }
                    // ✅ 드래그-앤-드롭 정렬
                    .onMove(perform: moveExpressions)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 300)

            Section("표현 검색 & 연결") {
                HStack {
                    TextField("검색", text: $eq).onSubmit { Task { await doExprSearch() } }
                    Button("검색") { Task { await doExprSearch() } }
                }
                ForEach(esearch, id: \.id) { e in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(e.text).bold()
                            let m = e.meanings
                            if !m.isEmpty {
                                Text(m.joined(separator: ", ")).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("연결") { Task { await attachExpression(e.id) } }
                    }
                }
                NavigationLink("+ 새 표현 만들기") {
                    ExpressionCreateScreen(onCreated: { e in
                        Task { await attachExpression(e.id) }
                    })
                }
            }
            // ▲▲▲ 표현(Expressions) 섹션 추가 ▲▲▲
        }
        .navigationTitle(model?.name ?? "상세")
        .task { await load() }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
        .alert("레슨 삭제?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                print("Lesson deleted")
                Task { await remove() }
            }
            Button("취소", role: .cancel) { }
        }
    }

    private func load() async {
        do {
            let l = try await APIClient.shared.lesson(id: lessonId)
            print("lession: \(l)")
            model = l
            name = l.name; unit = unit; level = l.level
            topic = l.topic ?? ""; grammar = l.grammar_main ?? ""
            exprs = l.expressions ?? []
        } catch { self.error = (error as NSError).localizedDescription }
    }
    private func save() async {
        guard var l = model else { return }
        l.name = name; l.unit = unit; l.level = level; l.topic = topic; l.grammar_main = grammar
        do { model = try await APIClient.shared.updateLesson(id: lessonId, payload: l) }
        catch { self.error = (error as NSError).localizedDescription }
    }
    private func remove() async {
        do { try await APIClient.shared.deleteLesson(id: lessonId) }
        catch { self.error = (error as NSError).localizedDescription }
    }

    // 단어 검색/연결/제거 (기존)
    private func doSearch() async {
        do { search = try await APIClient.shared.searchWords(q: q) }
        catch { self.error = (error as NSError).localizedDescription }
    }
    private func attach(_ wordId: Int) async {
        do {
            try await APIClient.shared.attachWord(lessonId: lessonId, wordId: wordId)
            await load()
        } catch { self.error = (error as NSError).localizedDescription }
    }
    private func detach(_ wordId: Int) async {
        do {
            try await APIClient.shared.detachWord(lessonId: lessonId, wordId: wordId)
            await load()
        } catch { self.error = (error as NSError).localizedDescription }
    }

    // ▼▼▼ 표현 검색/연결/제거 추가 ▼▼▼
    private func doExprSearch() async {
        do { esearch = try await APIClient.shared.unassignedExpressions(q: eq) }
        catch { self.error = (error as NSError).localizedDescription }
    }
    private func attachExpression(_ expressionId: Int) async {
        do {
            try await APIClient.shared.attachExpression(lessonId: lessonId, expressionId: expressionId)
            await load()
        } catch { self.error = (error as NSError).localizedDescription }
    }
    private func detachExpression(_ expressionId: Int) async {
        do {
            try await APIClient.shared.detachExpression(lessonId: lessonId, expressionId: expressionId)
            await load()
        } catch { self.error = (error as NSError).localizedDescription }
    }
    // ✅ 드래그 이동 처리 + 서버 반영
    private func moveExpressions(from source: IndexSet, to destination: Int) {
        exprs.move(fromOffsets: source, toOffset: destination)
        Task { await persistExprOrder() }
    }

    // ✅ 서버에 순서 저장 (예시 API)
    private func persistExprOrder() async {
        do {
            let ids = exprs.map { $0.id }
            try await APIClient.shared.reorderExpressions(lessonId: lessonId, expressionIds: ids)
        } catch {
            self.error = (error as NSError).localizedDescription
            // 에러 시 서버 상태와 불일치가 생길 수 있으므로 새로고침 권장
        }
    }
}
