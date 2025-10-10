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

    // 기본 필드
    @State private var unit = 1
    @State private var level = 1
    @State private var grammar = ""

    // 단어 검색 (필요 시 주석 해제해서 사용)
    @State private var q = ""
    @State private var search: [Word] = []

    // 단어 검색/연결
    @State private var wq = ""
    @State private var wsearch: [Word] = []

    @State private var words: [Word] = []

    @State private var error: String?
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        Form {
            // MARK: 기본 정보
            Section("기본 정보") {
                Stepper("Unit: \(unit)", value: $unit, in: 1...100)              // ✅ unit에 바인딩
                Stepper("레벨: \(level)", value: $level, in: 1...100)
                TextField("문법", text: $grammar)
                Button("수정 저장") { Task { await save() } }
                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    Text("레슨 삭제")
                }
            }

            // MARK: 단어 목록
            List {
                Section("단어 (\(words.count))") {
                    ForEach(words, id: \.id) { w in
                        NavigationLink {
                            WordDetailScreen(wordId: w.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(w.text).bold()

                                    // 🔤 번역 요약 표시: "[ko, en, ja]" 혹은 첫 번역 텍스트 일부
                                    if w.translations.isEmpty == false {
                                        // 언어코드 요약
                                        let langs = w.translations.map { $0.lang_code }.joined(separator: ", ")
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
                                Button("제거") { Task { await detach(w.id) } }
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
                    TextField("검색", text: $wq).onSubmit { Task { await doWordSearch() } }
                    Button("검색") { Task { await doWordSearch() } }
                }
                ForEach(wsearch, id: \.id) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(w.text).bold()
                            if w.translations.isEmpty == false {
                                let langs = w.translations.map { $0.lang_code }.joined(separator: ", ")
                                Text("[\(langs)]")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("연결") { Task { await attach(w.id) } }
                    }
                }
                NavigationLink("+ 새 단어 만들기") {
                    WordCreateScreen(onCreated: { w in
                        Task { await attach(w.id) }
                    })
                }
            }

            // === 단어 관련 섹션은 필요 시 복구 ===
        }
        .navigationTitle("레슨 상세")
        .task { await load() }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .alert("레슨 삭제?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) { Task { await remove() } }
            Button("취소", role: .cancel) { }
        }
    }

    // MARK: - Intent
    private func load() async {
        do {
            let l = try await LessonDataSource.shared.lesson(id: lessonId)
            model = l
            unit = l.unit
            level = l.level
            grammar = l.grammar ?? ""
            words = l.words
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func save() async {
        guard var l = model else { return }
        l.unit = unit
        l.level = level
        l.grammar = grammar
        do {
            model = try await LessonDataSource.shared.updateLesson(id: lessonId, payload: l)
            // 서버가 words를 함께 돌려준다면 리스트 갱신
            words = model?.words ?? words
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func remove() async {
        do {
            try await LessonDataSource.shared.deleteLesson(id: lessonId)
            // 상위에서 pop 처리 권장
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    // MARK: 단어 검색/연결/제거 (필요 시 사용)
    private func doSearch() async {
        do { search = try await WordDataSource.shared.searchWords(q: q) }
        catch { self.error = (error as NSError).localizedDescription }
    }
    private func attach(_ wordId: Int) async {
        do {
            _ = try await LessonDataSource.shared.attachWord(lessonId: lessonId, wordId: wordId)
            await load()
        } catch { self.error = (error as NSError).localizedDescription }
    }
    private func detach(_ wordId: Int) async {
        do {
            _ = try await LessonDataSource.shared.detachWord(lessonId: lessonId, wordId: wordId)
            await load()
        } catch { self.error = (error as NSError).localizedDescription }
    }

    // MARK: 단어 검색/연결
    private func doWordSearch() async {
        do { wsearch = try await WordDataSource.shared.searchWords(q: wq) }
        catch { self.error = (error as NSError).localizedDescription }
    }
}
