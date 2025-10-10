//
//  LessonRowView.swift
//  LessonClient
//
//  Created by ymj on 9/9/25.
//

import SwiftUI

struct LessonRowView: View {
    let lesson: Lesson

    @State private var previews: [WordPreview] = []
    @State private var isLoading = false
    @State private var rowError: String?

    /// 한 레슨당 최대 몇 개의 단어/예문을 미리 보여줄지
    private let maxWords = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 제목줄
            HStack(alignment: .firstTextBaseline) {
                Text("Unit \(lesson.unit)")
                    .font(.headline)
                Spacer()
                // Display lesson's grammar or an empty string when grammar is nil
                Text(lesson.grammar ?? "")
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
            // 레슨의 단어 목록 가져오기
            let loadedLesson = try await LessonDataSource.shared.lesson(id: lesson.id)
            let words = loadedLesson.words.prefix(maxWords)

            // 각 표현의 첫 예문만 비동기 병렬로 가져오기
            var tmp: [WordPreview] = []
            tmp.reserveCapacity(words.count)

            try await withThrowingTaskGroup(of: (Int, WordPreview?).self) { group in
                for (index, word) in words.enumerated() {
                    group.addTask {
                        let examples = word.examples
                        let first = examples.first
                        return (
                            index,
                            WordPreview(
                                id: word.id,
                                text: word.text,
                                exampleEN: first?.translations.first(where: { $0.lang_code == "en" })?.text,
                                exampleKO: first?.translations.first(where: { $0.lang_code == "ko" })?.text
                            )
                        )
                    }
                }

                // 결과를 인덱스 위치에 채워 넣기
                var buffer = Array<WordPreview?>(repeating: nil, count: words.count)
                for try await (index, preview) in group {
                    buffer[index] = preview
                }
                tmp = buffer.compactMap { $0 }
            }

            self.previews = tmp
        } catch {
            self.rowError = (error as NSError).localizedDescription
        }
    }

    // 미리보기 전용 경량 모델
    private struct WordPreview: Identifiable {
        let id: Int
        let text: String
        let exampleEN: String?
        let exampleKO: String?
    }
}
