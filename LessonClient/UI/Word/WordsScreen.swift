// WordsScreen.swift
import SwiftUI

struct WordsScreen: View {
    @State private var items: [Word] = []
    @State private var q = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("단어 검색", text: $q)
                    Button("검색") { Task { await search() } }
                }.padding(.horizontal)

                List(items) { w in
                    NavigationLink(w.text) { WordDetailScreen(wordId: w.id) }
                    .badge(w.meanings.joined(separator: ", "))
                }
                .task { await load() }
                
                NavigationLink("+ 새 단어", destination: WordEditScreen(onCreated: { w in
                    items.insert(w, at: 0)
                }))
                .padding()

                NavigationLink("+ 여러 개 추가", destination: BulkWordImportScreen(onImported: { list in
                    // 새로 추가된 단어들을 상단에 표시
                    items.insert(contentsOf: list, at: 0)
                }))
                .padding(.horizontal)
            }
            .navigationTitle("단어")
        }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func load() async { do { items = try await APIClient.shared.words() } catch { self.error = (error as NSError).localizedDescription } }
    private func search() async { do { items = try await APIClient.shared.searchWords(q: q) } catch { self.error = (error as NSError).localizedDescription } }
}

struct WordDetailScreen: View {
    let wordId: Int
    @State private var model: Word?
    @State private var en = ""; @State private var ko = ""
    @State private var error: String?

    var body: some View {
        Form {
            if let w = model {
                Section("단어") {
                    TextField("텍스트", text: Binding(get: { w.text }, set: { model?.text = $0 }))
                    TextField("뜻(쉼표로 구분)", text: Binding(
                        get: { w.meanings.joined(separator: ", ") },
                        set: { model?.meanings = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                    Button("수정 저장") { Task { await save() } }
                    Button(role: .destructive) { Task { await remove() } } label: { Text("삭제") }
                }
            }
        }
        .navigationTitle(model?.text ?? "단어")
        .task { await load() }
        .alert("오류", isPresented: .constant(error != nil)) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func load() async {
        do {
            model = try await APIClient.shared.word(id: wordId)
        } catch { self.error = (error as NSError).localizedDescription }
    }
    private func save() async {
        guard let w = model else { return }
        do { model = try await APIClient.shared.updateWord(id: w.id, text: w.text, meanings: w.meanings) }
        catch { self.error = (error as NSError).localizedDescription }
    }
    private func remove() async {
        guard let w = model else { return }
        do { try await APIClient.shared.deleteWord(id: w.id) }
        catch { self.error = (error as NSError).localizedDescription }
    }
}

struct WordEditScreen: View {
    var onCreated: ((Word) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var meanings = ""
    @State private var error: String?

    var body: some View {
        Form {
            TextField("단어", text: $text)
            TextField("뜻(줄바꿈/쉼표)", text: $meanings)
            Button("생성") {
                Task {
                    do {
                        let list = meanings
                            .split(whereSeparator: { $0 == "," || $0.isNewline })
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        let w = try await APIClient.shared.createWord(text: text, meanings: list)
                        onCreated?(w)
                        dismiss()
                    } catch { self.error = (error as NSError).localizedDescription }
                }
            }
            if let e = error { Text(e).foregroundStyle(.red) }
        }
        .navigationTitle("새 단어")
    }
}

struct BulkWordImportScreen: View {
    var onImported: (([Word]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var isImporting = false
    @State private var error: String?

    private let example = "and^그리고\nmy^나의 / 내\nbag ^ 가방\nphone ^ 전화 / 휴대폰"

    var body: some View {
        Form {
            Section("포맷과 예시") {
                Text("각 줄에 `영어^뜻1 / 뜻2` 형태로 입력하세요. 공백은 자동으로 정리됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(example)
                    .font(.footnote)
                    .monospaced()
                    .padding(.vertical, 4)
            }

            Section("붙여넣기") {
                TextEditor(text: $input)
                    .frame(minHeight: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    )
            }

            if let preview = previewPairs(), !preview.isEmpty {
                Section("미리보기 (\(preview.count)개)") {
                    ForEach(Array(preview.enumerated()), id: \.0) { _, p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.0)
                            Text(p.1.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button {
                Task { await importAll() }
            } label: {
                if isImporting { ProgressView() } else { Text("일괄 추가") }
            }
            .disabled(isImporting || previewPairs()?.isEmpty != false)

            if let e = error { Text(e).foregroundStyle(.red) }
        }
        .navigationTitle("여러 개 추가")
    }

    private func previewPairs() -> [(String, [String])]? {
        let lines = input
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        var result: [(String, [String])] = []
        for line in lines {
            // split with '^' (first occurrence only)
            guard let caretIndex = line.firstIndex(of: "^") else { continue }
            let left = String(line[..<caretIndex]).trimmingCharacters(in: .whitespaces)
            let right = String(line[line.index(after: caretIndex)...]).trimmingCharacters(in: .whitespaces)
            guard !left.isEmpty, !right.isEmpty else { continue }

            // meanings can be separated by '/', ',', or newlines
            let parts = right
                .split(whereSeparator: { $0 == "/" || $0 == "," || $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if !parts.isEmpty { result.append((left, parts)) }
        }
        return result
    }

    private func importAll() async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        let pairs = previewPairs() ?? []
        var created: [Word] = []
        for (text, meanings) in pairs {
            do {
                let w = try await APIClient.shared.createWord(text: text, meanings: meanings)
                created.append(w)
            } catch {
                // 개별 실패는 스킵하고 마지막에 에러 표시
                self.error = (error as NSError).localizedDescription
            }
        }
        if !created.isEmpty { onImported?(created) }
        dismiss()
    }
}
