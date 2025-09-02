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
                
                NavigationLink("+ 새 단어", destination: WordEditScreen())
                    .padding()
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
    @State private var examples: [ExampleItem] = []
    @State private var en = ""; @State private var ko = ""
    @State private var error: String?

    var body: some View {
        Form {
            if var w = model {
                Section("단어") {
                    TextField("텍스트", text: Binding(get: { w.text }, set: { model?.text = $0 }))
                    TextField("뜻(쉼표로 구분)", text: Binding(
                        get: { w.meanings.joined(separator: ", ") },
                        set: { model?.meanings = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                    Button("수정 저장") { Task { await save() } }
                    Button(role: .destructive) { Task { await remove() } } label: { Text("삭제") }
                }
                Section("예문") {
                    ForEach(examples) { ex in
                        VStack(alignment: .leading) {
                            Text(ex.sentence_en)
                            if let tr = ex.translation_ko { Text(tr).foregroundStyle(.secondary) }
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
            examples = try await APIClient.shared.examples(wordId: wordId)
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
    private func addExample() async {
        guard let w = model else { return }
        do { let ex = try await APIClient.shared.createExample(wordId: w.id, en: en, ko: ko.isEmpty ? nil : ko)
             examples.insert(ex, at: 0); en = ""; ko = "" }
        catch { self.error = (error as NSError).localizedDescription }
    }
    private func updateExample(_ ex: ExampleItem) async {
        do { _ = try await APIClient.shared.updateExample(exampleId: ex.id, en: ex.sentence_en, ko: ex.translation_ko) }
        catch { self.error = (error as NSError).localizedDescription }
    }
    private func deleteExample(_ id: Int) async {
        do { try await APIClient.shared.deleteExample(exampleId: id); examples.removeAll { $0.id == id } }
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
