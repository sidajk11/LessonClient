//
//  ExpressionDetailScreen.swift
//  LessonClient
//
//  Created by ymj on 9/9/25.
//

import SwiftUI

struct ExpressionDetailScreen: View {
    let expressionId: Int
    @State private var model: Expression?
    @State private var examples: [ExampleItem] = []
    @State private var en = ""; @State private var ko = ""
    @State private var meaningsText: String = ""
    @State private var error: String?
    
    @State private var levelLinkText: String = ""
    @State private var isLinking = false
    @State private var info: String?


    var body: some View {
        Form {
            if let w = model {
                Section("표현") {
                    TextField("텍스트", text: Binding(
                        get: { w.text },
                        set: { model?.text = $0 }
                    ))
                    TextField("뜻(쉼표 / 슬래시)", text: $meaningsText)
                        .onChange(of: meaningsText) { _ in syncMeaningsToModel() }
                        .onAppear { meaningsText = w.meanings.joined(separator: ", ") }

                    Button("수정 저장") { Task { await save() } }
                    Button(role: .destructive) { Task { await remove() } } label: { Text("삭제") }
                }
                Section("예문") {
                    ForEach(examples) { ex in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ex.sentence_en)
                            if let tr = ex.translation { Text(tr).foregroundStyle(.secondary) }
                            HStack {
                                Button("수정") { Task { await updateExample(ex) } }
                                Button("삭제", role: .destructive) { Task { await deleteExample(ex.id) } }
                            }
                        }
                    }
                    HStack {
                        TextField("영어 문장", text: $en)
                        TextField("번역", text: $ko)
                        Button("추가") { Task { await addExample() } }
                    }
                }
                Section("레슨 레벨 연결") {
                    HStack(spacing: 8) {
                        TextField("레벨 (예: 3)", text: $levelLinkText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onChange(of: levelLinkText) { levelLinkText = $0.filter(\.isNumber) }

                        Button(isLinking ? "적용 중…" : "적용") {
                            Task { await linkToLevel() }
                        }
                        .disabled(isLinking || levelLinkText.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    Text("입력한 레벨의 레슨들에만 이 표현을 연결하고, 다른 레벨 레슨과의 연결은 모두 해제합니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }

            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(model?.text ?? "표현")
        .task { await load() }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
        .alert("완료", isPresented: .constant(info != nil)) {
            Button("확인") { info = nil }
        } message: { Text(info ?? "") }

    }

    private func load() async {
        do {
            let w = try await APIClient.shared.expression(id: expressionId)
            model = w
            meaningsText = w.meanings.joined(separator: ", ")
            examples = try await APIClient.shared.examples(expressionId: expressionId)
        } catch { self.error = (error as NSError).localizedDescription }
    }

    private func save() async {
        guard var w = model else { return }
        w.meanings = parseMeanings(meaningsText)
        do {
            model = try await APIClient.shared.updateExpression(id: w.id, text: w.text, meanings: w.meanings)
            meaningsText = model?.meanings.joined(separator: ", ") ?? ""
        } catch { self.error = (error as NSError).localizedDescription }
    }

    private func remove() async {
        guard let w = model else { return }
        do {
            try await APIClient.shared.deleteExpression(id: w.id)
        } catch { self.error = (error as NSError).localizedDescription }
    }

    private func addExample() async {
        guard let w = model else { return }
        do {
            let ex = try await APIClient.shared.createExample(expressionId: w.id, en: en, ko: ko.isEmpty ? nil : ko)
            examples.insert(ex, at: 0)
            en = ""; ko = ""
        } catch { self.error = (error as NSError).localizedDescription }
    }

    private func updateExample(_ ex: ExampleItem) async {
        do {
            _ = try await APIClient.shared.updateExample(exampleId: ex.id, en: ex.sentence_en, ko: ex.translation)
        } catch { self.error = (error as NSError).localizedDescription }
    }

    private func deleteExample(_ id: Int) async {
        do {
            try await APIClient.shared.deleteExample(exampleId: id)
            examples.removeAll { $0.id == id }
        } catch { self.error = (error as NSError).localizedDescription }
    }

    private func parseMeanings(_ text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "/" || $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func syncMeaningsToModel() {
        guard model != nil else { return }
        model?.meanings = parseMeanings(meaningsText)
    }
    
    private func linkToLevel() async {
        guard let targetLevel = Int(levelLinkText.trimmingCharacters(in: .whitespaces)) else {
            self.error = "레벨은 숫자로 입력해 주세요."
            return
        }
        guard let exprId = model?.id else { return }

        isLinking = true
        defer { isLinking = false }

        do {
            // 타겟 레벨 레슨
            let targetLessons = try await APIClient.shared.lessons(levelMin: targetLevel, levelMax: targetLevel)
            // 전체 레슨(현재 연결 파악용)
            let allLessons = try await APIClient.shared.lessons()

            // 현재 이 표현이 연결된 레슨들
            let currentlyLinked = allLessons.filter { l in
                (l.expressions ?? []).contains(where: { $0.id == exprId })
            }

            // 항상 해제: 타겟 레벨이 아닌 레슨과의 연결
            let toDetach = currentlyLinked.filter { $0.level != targetLevel }

            // 타겟 레벨에서 아직 안 붙어있는 레슨에만 attach
            let toAttach = targetLessons.filter { l in
                !(l.expressions ?? []).contains(where: { $0.id == exprId })
            }

            // 1) 해제 먼저
            try await withThrowingTaskGroup(of: Void.self) { group in
                for l in toDetach {
                    group.addTask {
                        try await APIClient.shared.detachExpression(lessonId: l.id, expressionId: exprId)
                    }
                }
                for try await _ in group {}
            }

            // 2) 연결
            try await withThrowingTaskGroup(of: Void.self) { group in
                for l in toAttach {
                    group.addTask {
                        try await APIClient.shared.attachExpression(lessonId: l.id, expressionId: exprId)
                    }
                }
                for try await _ in group {}
            }

            self.info = "레벨 \(targetLevel) 적용 완료 — 연결 \(toAttach.count)개, 해제 \(toDetach.count)개."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
