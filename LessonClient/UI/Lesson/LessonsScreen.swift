// LessonsScreen.swift
import SwiftUI
import AppKit

struct LessonsScreen: View {
    @State private var items: [Lesson] = []
    @State private var error: String?

    // ▼ (이전 답변에서 만든) 레벨 범위 필터가 있었다면 유지
    @State private var minLevelText = ""
    @State private var maxLevelText = ""

    // ▼ 복사 진행/완료 표시
    @State private var isCopying = false
    @State private var copyInfo: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {

                // ===== 필터/액션 줄 =====
                HStack(spacing: 8) {
                    TextField("최소 레벨", text: $minLevelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: minLevelText) { minLevelText = $0.filter(\.isNumber) }
                        .onSubmit { Task { await search() } }

                    TextField("최대 레벨", text: $maxLevelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: maxLevelText) { maxLevelText = $0.filter(\.isNumber) }
                        .onSubmit { Task { await search() } }

                    Button("검색") { Task { await search() } }
                        .buttonStyle(.borderedProminent)

                    Button("초기화") {
                        minLevelText = ""; maxLevelText = ""
                        Task { await load() }
                    }

                    // ▼ 요청하신 “복사” 버튼
                    Button {
                        Task { await copyLessons() }
                    } label: {
                        if isCopying {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("복사")
                        }
                    }
                    .disabled(isCopying)
                }
                .padding(.horizontal)

                // ===== 목록 =====
                ZStack(alignment: .bottomTrailing) {
                    List(items) { l in
                        NavigationLink {
                            LessonDetailScreen(lessonId: l.id)
                        } label: {
                            LessonRowView(lesson: l)   // ← 여기!
                        }
                        .badge("Lv.\(l.level)")
                    }
                    .task { await load() }

                    // ===== 플로팅 버튼들 =====
                    VStack(spacing: 12) {
                        NavigationLink {
                            LessonBulkAddScreen { newLesson in
                                items.insert(newLesson, at: 0)
                            }
                        } label: {
                            Image(systemName: "text.badge.plus")
                                .font(.title3)
                                .padding(12)
                                .background(Color.accentColor.opacity(0.9))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }

                        NavigationLink {
                            LessonEditScreen { newLesson in
                                items.insert(newLesson, at: 0)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("레슨")
        }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
        .alert("복사 완료", isPresented: .constant(copyInfo != nil)) {
            Button("OK") { copyInfo = nil }
        } message: { Text(copyInfo ?? "") }
    }

    // MARK: - Data

    private func load() async {
        do { items = try await APIClient.shared.lessons() }
        catch { self.error = (error as NSError).localizedDescription }
    }

    private func search() async {
        do {
            let minV = Int(minLevelText.trimmingCharacters(in: .whitespaces))
            let maxV = Int(maxLevelText.trimmingCharacters(in: .whitespaces))
            if let minV, let maxV, minV > maxV {
                self.error = "최소 레벨이 최대 레벨보다 큽니다."
                return
            }
            // 서버가 level_min/level_max를 지원한다고 가정
            items = try await APIClient.shared.lessons(levelMin: minV, levelMax: maxV)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    // MARK: - Copy / Export

    private func copyLessons() async {
        guard !isCopying else { return }
        isCopying = true
        defer { isCopying = false }

        do {
            let (text, lessonCnt, exprCnt, exCnt) = try await buildExportText(for: items)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
            self.copyInfo = "복사되었습니다. 레슨 \(lessonCnt)개, 표현 \(exprCnt)개, 예문 \(exCnt)개."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    /// 지정한 레슨 배열을 요청하신 포맷 문자열로 변환
    /// 포맷:
    /// level
    /// topic
    /// main grammar
    ///
    /// exprText^meaning
    /// ...
    ///
    /// exprText
    /// EN.^KO.
    /// (빈 줄)
    private func buildExportText(for lessons: [Lesson]) async throws -> (String, Int, Int, Int) {
        // 정렬: level 오름차순, id 오름차순
        let sorted = lessons.sorted { ($0.level, $0.id) < ($1.level, $1.id) }

        var lines: [String] = []
        var totalExpr = 0
        var totalEx = 0

        for lesson in sorted {
            // 헤더 3줄
            lines.append("\(lesson.level)")
            lines.append(lesson.topic ?? "")
            lines.append(lesson.grammar_main ?? "")
            lines.append("") // 빈 줄

            let exprs = lesson.expressions ?? []

            // 표현 목록: text^첫 뜻(없으면 text)
            for e in exprs {
                let firstMeaning = (e.meanings ?? []).first ?? e.text
                lines.append("\(e.text)^\(firstMeaning)")
            }
            lines.append("")

            // 각 표현의 예문 가져오기 (병렬)
            var examplesByExpr: [Int: [ExampleItem]] = [:]
            try await withThrowingTaskGroup(of: (Int, [ExampleItem]).self) { group in
                for e in exprs {
                    group.addTask {
                        let arr = try await APIClient.shared.examples(expressionId: e.id)
                        return (e.id, arr)
                    }
                }
                for try await (exprId, arr) in group {
                    examplesByExpr[exprId] = arr
                }
            }

            // 표현 블록
            for e in exprs {
                totalExpr += 1
                lines.append(e.text)
                let arr = examplesByExpr[e.id] ?? []
                for ex in arr {
                    totalEx += 1
                    if let ko = ex.translation_ko, !ko.isEmpty {
                        lines.append("\(ex.sentence_en)^\(ko)")
                    } else {
                        lines.append("\(ex.sentence_en)")
                    }
                }
                lines.append("") // 표현 사이 빈 줄
            }

            // 레슨 사이에도 빈 줄 1개 (이미 마지막에 빈 줄 있으므로 추가 X)
        }

        // 마지막 공백 줄 정리
        while lines.last?.isEmpty == true { _ = lines.popLast() }
        let text = lines.joined(separator: "\n")
        return (text, sorted.count, totalExpr, totalEx)
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
    // ▼▼▼ expressions용 상태 추가 ▼▼▼
    @State private var eq = ""
    @State private var esearch: [Expression] = []
    // ▲▲▲ expressions용 상태 추가 ▲▲▲
    @State private var error: String?

    var body: some View {
        Form {
            // 기존 섹션 ...
            Section("기본 정보") {
                TextField("이름", text: $name)
                Stepper("레벨: \(level)", value: $level, in: 1...100)
                TextField("토픽", text: $topic)
                TextField("문법", text: $grammar)
                Button("수정 저장") { Task { await save() } }
                Button(role: .destructive, action: { Task { await remove() } }) { Text("레슨 삭제") }
            }

            // 단어 섹션 (기존)
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

            // 단어 검색/연결 (기존)
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

            // ▼▼▼ 표현(Expressions) 섹션 추가 ▼▼▼
            if let exprs = model?.expressions {
                Section("표현 (\(exprs.count))") {
                    ForEach(exprs, id: \.id) { e in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(e.text).bold()
                                // 필요 시 부가정보 표시 (형태는 모델에 맞춰 수정)
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
            }

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
    }

    private func load() async {
        do {
            let l = try await APIClient.shared.lesson(id: lessonId)
            print("lession: \(l)")
            model = l
            name = l.name; level = l.level
            topic = l.topic ?? ""; grammar = l.grammar_main ?? ""
        } catch { self.error = (error as NSError).localizedDescription }
    }
    private func save() async {
        guard var l = model else { return }
        l.name = name; l.level = level; l.topic = topic; l.grammar_main = grammar
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
        do { esearch = try await APIClient.shared.searchExpressions(q: eq) }
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
    // ▲▲▲ 표현 검색/연결/제거 추가 ▲▲▲
}
