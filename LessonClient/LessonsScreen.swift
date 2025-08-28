// LessonsScreen.swift
import SwiftUI

struct LessonsScreen: View {
    @State private var items: [Lesson] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List(items) { l in
                NavigationLink(l.name) { LessonDetailScreen(lessonId: l.id) }
                .badge("Lv.\(l.level)")
            }
            .navigationTitle("레슨")
            .task { await load() }
            .overlay(alignment: .bottomTrailing) {
                // 레슨 생성 API가 없다면 상세에서 수정만 제공
                EmptyView()
            }
        }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func load() async {
        do { items = try await APIClient.shared.lessons() }
        catch { self.self.error = (error as NSError).localizedDescription }
    }
}

struct LessonDetailScreen: View {
    let lessonId: Int
    @State private var model: Lesson?
    @State private var name = ""
    @State private var level = 1
    @State private var topic = ""
    @State private var grammar = ""
    @State private var q = ""
    @State private var search: [Word] = []
    @State private var error: String?

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("이름", text: $name)
                Stepper("레벨: \(level)", value: $level, in: 1...100)
                TextField("토픽", text: $topic)
                TextField("문법", text: $grammar)
                Button("수정 저장") { Task { await save() } }
                Button(role: .destructive, action: { Task { await remove() } }) { Text("레슨 삭제") }
            }
            if let words = model?.words {
                Section("단어 (\(words.count))") {
                    ForEach(words, id: \.id) { w in
                        HStack {
                            Text(w.text)
                            Spacer()
                            Button("제거") { Task { await detach(w.id) } }
                        }
                    }
                }
            }
            Section("단어 검색 & 연결") {
                HStack {
                    TextField("검색", text: $q).onSubmit { Task { await doSearch() } }
                    Button("검색") { Task { await doSearch() } }
                }
                ForEach(search, id: \.id) { w in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(w.text).bold()
                            Text(w.meanings.joined(separator: ", ")).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("연결") { Task { await attach(w.id) } }
                    }
                }
                NavigationLink("+ 새 단어 만들기") {
                    WordEditScreen(onCreated: { w in
                        Task { await attach(w.id) }
                    })
                }
            }
        }
        .navigationTitle(model?.name ?? "상세")
        .task { await load() }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func load() async {
        do {
            let l = try await APIClient.shared.lesson(id: lessonId)
            model = l
            name = l.name; level = l.level
            topic = l.topic ?? ""; grammar = l.grammar_main ?? ""
        } catch { self.self.error = (error as NSError).localizedDescription }
    }
    private func save() async {
        guard var l = model else { return }
        l.name = name; l.level = level; l.topic = topic; l.grammar_main = grammar
        do { model = try await APIClient.shared.updateLesson(id: lessonId, payload: l) }
        catch { self.self.error = (error as NSError).localizedDescription }
    }
    private func remove() async {
        do { try await APIClient.shared.deleteLesson(id: lessonId) }
        catch { self.self.error = (error as NSError).localizedDescription }
    }
    private func doSearch() async {
        do { search = try await APIClient.shared.searchWords(q: q) }
        catch { self.self.error = (error as NSError).localizedDescription }
    }
    private func attach(_ wordId: Int) async {
        do { try await APIClient.shared.attachWord(lessonId: lessonId, wordId: wordId); await load() }
        catch { self.self.error = (error as NSError).localizedDescription }
    }
    private func detach(_ wordId: Int) async {
        do { try await APIClient.shared.detachWord(lessonId: lessonId, wordId: wordId); await load() }
        catch { self.self.error = (error as NSError).localizedDescription }
    }
}
