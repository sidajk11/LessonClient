//
//  ExamplesSearchScreen..swift
//  LessonClient
//
//  Created by 정영민 on 8/28/25.
//

import SwiftUI

struct ExamplesSearchScreen: View {
    @State private var q = ""
    @State private var items: [APIClient.ExampleRow] = []
    @State private var error: String?

    var body: some View {
        VStack {
            HStack {
                TextField("예문 검색", text: $q)
                Button("검색") { Task { await search() } }
            }.padding()

            List(items) { row in
                VStack(alignment: .leading) {
                    Text(row.sentence_en)
                    if let ko = row.translation_ko { Text(ko).foregroundStyle(.secondary) }
                    Text("단어: \(row.word_text)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("예문")
        .alert("오류", isPresented: .constant(error != nil)) { Button("확인") { error = nil } } message: { Text(error ?? "") }
    }

    private func search() async {
        do { items = try await APIClient.shared.searchExamples(q: q) }
        catch let err {
            self.error = err.localizedDescription
        }
    }
}
