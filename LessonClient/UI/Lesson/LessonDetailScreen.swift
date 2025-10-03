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
    @State private var name = ""
    @State private var unit = 1
    @State private var level = 1
    @State private var topic = ""
    @State private var grammar = ""

    // 단어 검색 (필요 시 주석 해제해서 사용)
    @State private var q = ""
    @State private var search: [Word] = []

    // 표현 검색/연결
    @State private var eq = ""
    @State private var esearch: [Expression] = []

    @State private var exprs: [Expression] = []

    @State private var error: String?
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        Form {
            // MARK: 기본 정보
            Section("기본 정보") {
                TextField("이름", text: $name)
                Stepper("Unit: \(unit)", value: $unit, in: 1...100)              // ✅ unit에 바인딩
                Stepper("레벨: \(level)", value: $level, in: 1...100)
                TextField("토픽", text: $topic)
                TextField("문법", text: $grammar)
                Button("수정 저장") { Task { await save() } }
                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    Text("레슨 삭제")
                }
            }

            // MARK: 표현 목록 (정렬 지원)
            List {
                Section("표현 (\(exprs.count))") {
                    ForEach(exprs, id: \.id) { e in
                        NavigationLink {
                            WordDetailScreen(expressionId: e.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(e.text).bold()

                                    // 🔤 번역 요약 표시: "[ko, en, ja]" 혹은 첫 번역 텍스트 일부
                                    if e.translations.isEmpty == false {
                                        // 언어코드 요약
                                        let langs = e.translations.map { $0.lang_code }.joined(separator: ", ")
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
                                Button("제거") { Task { await detachExpression(e.id) } }
                            }
                        }
                    }
                    .onMove(perform: moveExpressions) // ✅ 드래그-앤-드롭 정렬
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 300)

            // MARK: 표현 검색 & 연결
            Section("표현 검색 & 연결") {
                HStack {
                    TextField("검색", text: $eq).onSubmit { Task { await doExprSearch() } }
                    Button("검색") { Task { await doExprSearch() } }
                }
                ForEach(esearch, id: \.id) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.text).bold()
                            if e.translations.isEmpty == false {
                                let langs = e.translations.map { $0.lang_code }.joined(separator: ", ")
                                Text("[\(langs)]")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("연결") { Task { await attachExpression(e.id) } }
                    }
                }
                NavigationLink("+ 새 표현 만들기") {
                    WordCreateScreen(onCreated: { e in
                        Task { await attachExpression(e.id) }
                    })
                }
            }

            // === 단어 관련 섹션은 필요 시 복구 ===
        }
        .navigationTitle(model?.name ?? "상세")
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
            name = l.name
            unit = l.unit          // ✅ 로딩 시 unit 올바르게 설정
            level = l.level
            topic = l.topic ?? ""
            grammar = l.grammar_main ?? ""
            exprs = l.expressions ?? []
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func save() async {
        guard var l = model else { return }
        l.name = name
        l.unit = unit
        l.level = level
        l.topic = topic
        l.grammar_main = grammar
        do {
            model = try await LessonDataSource.shared.updateLesson(id: lessonId, payload: l)
            // 서버가 expressions를 함께 돌려준다면 exprs도 갱신
            exprs = model?.expressions ?? exprs
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
        do { search = try await APIClient.shared.searchWords(q: q) }
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

    // MARK: 표현 검색/연결/제거
    private func doExprSearch() async {
        do {
            // 필요 시 특정 언어 제한을 걸고 싶으면 langs 전달: ["ko","en"]
            esearch = try await ExpressionDataSource.shared.unassignedExpressions(q: eq, limit: 20, langs: nil)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func attachExpression(_ expressionId: Int) async {
        do {
            _ = try await LessonDataSource.shared.attachExpression(lessonId: lessonId, expressionId: expressionId)
            await load()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func detachExpression(_ expressionId: Int) async {
        do {
            _ = try await LessonDataSource.shared.detachExpression(lessonId: lessonId, expressionId: expressionId)
            await load()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    // MARK: 순서 변경
    private func moveExpressions(from source: IndexSet, to destination: Int) {
        exprs.move(fromOffsets: source, toOffset: destination)
        Task { await persistExprOrder() }
    }

    private func persistExprOrder() async {
        do {
            let ids = exprs.map { $0.id }
            _ = try await LessonDataSource.shared.reorderExpressions(lessonId: lessonId, expressionIds: ids)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
