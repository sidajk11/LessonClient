//
//  LessonRowView.swift
//  LessonClient
//
//  Created by ymj on 9/9/25.
//

import SwiftUI

struct LessonRowView: View {
    let lesson: Lesson

    @State private var previews: [ExprPreview] = []
    @State private var isLoading = false
    @State private var rowError: String?

    // 한 레슨당 최대 몇 개의 표현/예문을 미리 보여줄지
    private let maxExpressions = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 제목줄
            HStack(alignment: .firstTextBaseline) {
                Text(lesson.name.isEmpty ? "Level \(lesson.level)" : lesson.name)
                    .font(.headline)
                Spacer()
                Text("Lv.\(lesson.level)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 미리보기(표현 + 예문)
            Group {
                if isLoading && previews.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("표현 불러오는 중…")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                } else if let e = rowError {
                    Text(e)
                        .foregroundStyle(.red)
                        .font(.footnote)
                } else if previews.isEmpty {
                    Text("표현 없음")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } else {
                    // 표현 1~2개, 각 표현의 첫 예문 1개까지 출력
                    ForEach(previews) { p in
                        HStack(spacing: 2) {
                            Text("• \(p.text): ")
                                .font(.subheadline).bold()
                            if let en = p.exampleEN {
                                Text(en)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .task { await loadPreviewsIfNeeded() } // 행이 보일 때 로드
    }

    // MARK: - Data loading
    @MainActor
    private func loadPreviewsIfNeeded() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // 레슨의 표현 목록 가져오기
            let detailed = try await APIClient.shared.expressionsOfLesson(lessonId: lesson.id)
            let exprs = (detailed.expressions ?? []).prefix(maxExpressions)

            // 각 표현의 첫 예문만 비동기 병렬로 가져오기
            var tmp: [ExprPreview] = []
            try await withThrowingTaskGroup(of: ExprPreview?.self) { group in
                for e in exprs {
                    group.addTask {
                        let examples = try await APIClient.shared.examples(expressionId: e.id)
                        let first = examples.first
                        return ExprPreview(
                            id: e.id,
                            text: e.text,
                            exampleEN: first?.sentence_en,
                            exampleKO: first?.translation_ko
                        )
                    }
                }
                for try await p in group {
                    if let p { tmp.append(p) }
                }
            }

            // 안정적인 순서 유지(표현 id 오름차순)
            tmp.sort { $0.id < $1.id }
            self.previews = tmp
        } catch {
            self.rowError = (error as NSError).localizedDescription
        }
    }

    // 미리보기 전용 경량 모델
    private struct ExprPreview: Identifiable {
        let id: Int
        let text: String
        let exampleEN: String?
        let exampleKO: String?
    }
}
