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
                        .badge("\(l.grammar_main ?? "")")
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
            lines.append("\(lesson.unit)")
            lines.append("\(lesson.level)")
            lines.append(lesson.topic ?? "")
            lines.append(lesson.grammar_main ?? "")
            lines.append("") // 빈 줄

            let exprs = lesson.expressions ?? []

            // 표현 목록: text^첫 뜻(없으면 text)
            for e in exprs {
                let firstMeaning = e.meanings.first ?? e.text
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
                    if let ko = ex.translation, !ko.isEmpty {
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
