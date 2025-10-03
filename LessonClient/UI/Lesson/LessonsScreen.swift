// LessonsScreen.swift
import SwiftUI
import AppKit

struct LessonsScreen: View {
    @State private var items: [Lesson] = []
    @State private var error: String?

    // ▼ (이전 답변에서 만든) 레벨 필터가 있었다면 유지
    @State private var levelText = ""

    // ▼ 복사 진행/완료 표시
    @State private var isCopying = false
    @State private var copyInfo: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {

                // ===== 필터/액션 줄 =====
                HStack(spacing: 8) {
                    TextField("레벨", text: $levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: levelText) { levelText = $0.filter(\.isNumber) }
                        .onSubmit { Task { await search() } }

                    Button("검색") { Task { await search() } }
                        .buttonStyle(.borderedProminent)

                    Button("초기화") {
                        levelText = ""
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
                        .badge("\(l.koTopic)")
                    }
                    .task { await load() }

                    // ===== 플로팅 버튼들 =====
                    VStack(spacing: 12) {
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
        do { items = try await LessonDataSource.shared.lessons() }
        catch { self.error = (error as NSError).localizedDescription }
    }

    private func search() async {
        do {
            let level = Int(levelText.trimmingCharacters(in: .whitespaces))
            // 서버가 level_min/level_max를 지원한다고 가정
            items = try await LessonDataSource.shared.lessons(level: level)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    // MARK: - Copy / Export

    private func copyLessons() async {
        
    }
}
