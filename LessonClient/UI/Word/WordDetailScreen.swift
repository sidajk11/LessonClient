import SwiftUI

// 편집용 로컬 모델
private struct EditableTranslation: Identifiable, Hashable {
    var id = UUID()
    var lang_code: String = ""
    var text: String = ""
}

struct WordDetailScreen: View {
    let expressionId: Int

    @State private var expression: Expression?
    @State private var examples: [Example] = []

    // 새 예문 입력
    @State private var newSentence: String = ""
    @State private var newTranslations: [EditableTranslation] = [EditableTranslation()]

    // 예문 편집
    @State private var editingExample: Example?
    @State private var editSentence: String = ""
    @State private var editTranslations: [EditableTranslation] = []
    @State private var showEditSheet: Bool = false

    // 상태
    @State private var error: String?
    @State private var info: String?

    var body: some View {
        Form {
            headerSection
            examplesSection
            addExampleSection
        }
        .navigationTitle(expression?.text ?? "표현")
        .task { await load() }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
        .alert("완료", isPresented: .constant(info != nil)) {
            Button("확인") { info = nil }
        } message: { Text(info ?? "") }
        .sheet(isPresented: $showEditSheet) {
            EditExampleSheet(
                sentence: $editSentence,
                translations: $editTranslations,
                onCancel: { showEditSheet = false },
                onSave: { Task { await applyEditExample() } }
            )
        }
    }

    // MARK: - Sections (쪼개기)

    @ViewBuilder
    private var headerSection: some View {
        if let e = expression {
            Section("표현") {
                TextField("기본 텍스트 (Expression.text)", text: Binding(
                    get: { e.text },
                    set: { expression?.text = $0 }
                ))

                HStack {
                    Button("기본 텍스트 저장") { Task { await saveBaseText() } }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                    Button(role: .destructive) { Task { await removeExpression() } } label: {
                        Text("표현 삭제")
                    }
                }

                if let lessonId = e.lessonId, let level = e.level {
                    Text("레슨 연결: #\(lessonId) (레벨 \(level))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("레슨에 연결되지 않음")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            Section { ProgressView().frame(maxWidth: .infinity) }
        }
    }

    @ViewBuilder
    private var examplesSection: some View {
        Section("예문") {
            if examples.isEmpty {
                Text("예문이 없습니다. 아래에서 예문을 추가해 보세요.")
                    .foregroundStyle(.secondary)
            } else {
                ExamplesList(
                    items: examples,
                    onEdit: { ex in startEdit(example: ex) },
                    onDelete: { id in Task { await deleteExample(id) } }
                )
            }
        }
    }

    @ViewBuilder
    private var addExampleSection: some View {
        Section("예문 추가") {
            TextField("영어 문장", text: $newSentence)
                .autocorrectionDisabled()

            EditableTranslationsList(
                translations: $newTranslations,
                minRows: 1,
                langPlaceholder: "언어코드 (예: ko, en, ja)",
                textPlaceholder: "번역"
            )

            HStack {
                Spacer()
                Button("예문 생성") { Task { await addExample() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreateDisabled)
            }
        }
    }

    private var isCreateDisabled: Bool {
        let sentenceOK = !newSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidTr = newTranslations.contains { !$0.lang_code.trimmed.isEmpty && !$0.text.trimmed.isEmpty }
        return !(sentenceOK && hasValidTr)
    }

    // MARK: - Intent

    private func load() async {
        do {
            let e = try await ExpressionDataSource.shared.expression(id: expressionId, langs: nil)
            expression = e
            examples = try await ExpressionDataSource.shared.examples(expressionId: expressionId, langs: nil)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func saveBaseText() async {
        guard let e = expression else { return }
        do {
            let updated = try await ExpressionDataSource.shared.updateExpression(
                id: e.id, text: e.text, meanings: [], langs: nil
            )
            expression = updated
            info = "기본 텍스트 저장 완료"
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func removeExpression() async {
        guard let e = expression else { return }
        do {
            try await ExpressionDataSource.shared.deleteExpression(id: e.id)
            info = "표현이 삭제되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func addExample() async {
        guard let e = expression else { return }
        do {
            let payload: [ExampleTranslation] = newTranslations
                .filter { !$0.lang_code.trimmed.isEmpty && !$0.text.trimmed.isEmpty }
                .map { ExampleTranslation(id: 0, text: $0.text.trimmed, lang_code: $0.lang_code.trimmed) }

            let created = try await ExpressionDataSource.shared.createExample(
                expressionId: e.id,
                sentence: newSentence.trimmed,
                translations: payload
            )
            examples.insert(created, at: 0)
            newSentence = ""
            newTranslations = [EditableTranslation()]
            info = "예문이 추가되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func startEdit(example: Example) {
        editingExample = example
        editSentence = example.sentence
        editTranslations = example.translations.map { EditableTranslation(lang_code: $0.lang_code, text: $0.text) }
        if editTranslations.isEmpty { editTranslations = [EditableTranslation()] }
        showEditSheet = true
    }

    private func applyEditExample() async {
        guard let ex = editingExample else { return }
        do {
            let payload: [ExampleTranslation] = editTranslations
                .filter { !$0.lang_code.trimmed.isEmpty && !$0.text.trimmed.isEmpty }
                .map { ExampleTranslation(id: 0, text: $0.text.trimmed, lang_code: $0.lang_code.trimmed) }

            let updated = try await ExpressionDataSource.shared.updateExample(
                exampleId: ex.id,
                sentence: editSentence.trimmed,
                translations: payload,
                langs: nil
            )
            if let idx = examples.firstIndex(where: { $0.id == ex.id }) {
                examples[idx] = updated
            }
            showEditSheet = false
            info = "예문이 수정되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    private func deleteExample(_ id: Int) async {
        do {
            try await ExpressionDataSource.shared.deleteExample(exampleId: id)
            examples.removeAll { $0.id == id }
            info = "예문이 삭제되었습니다."
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Subviews

private struct ExamplesList: View {
    let items: [Example]
    let onEdit: (Example) -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        ForEach(items) { ex in
            VStack(alignment: .leading, spacing: 6) {
                Text(ex.sentence).font(.body)

                if ex.translations.isEmpty {
                    Text("번역 없음").font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(ex.translations) { tr in
                            Text("[\(tr.lang_code)] \(tr.text)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("수정") { onEdit(ex) }
                    Button("삭제", role: .destructive) { onDelete(ex.id) }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct EditableTranslationsList: View {
    @Binding var translations: [EditableTranslation]
    var minRows: Int = 1
    var langPlaceholder: String = "언어코드"
    var textPlaceholder: String = "번역"

    var body: some View {
        VStack(alignment: .leading) {
            ForEach($translations) { $row in
                HStack {
                    TextField(langPlaceholder, text: $row.lang_code)
                        .frame(width: 140)
                    TextField(textPlaceholder, text: $row.text)
                    Button(role: .destructive) {
                        withAnimation {
                            if translations.count > minRows {
                                translations.removeAll { $0.id == row.id }
                            }
                        }
                    } label: { Image(systemName: "minus.circle") }
                    .disabled(translations.count <= minRows)
                }
            }
            Button {
                withAnimation { translations.append(.init()) }
            } label: {
                Label("번역 행 추가", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
    }
}

private struct EditExampleSheet: View {
    @Binding var sentence: String
    @Binding var translations: [EditableTranslation]
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("문장") {
                    TextField("영어 문장", text: $sentence)
                        .autocorrectionDisabled()
                }
                Section("번역들 (전면 교체)") {
                    EditableTranslationsList(translations: $translations)
                }
            }
            .navigationTitle("예문 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { onSave() }
                        .disabled(sentence.trimmed.isEmpty)
                }
            }
        }
    }
}

// MARK: - Utils

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
