import SwiftUI
import Combine

struct ExerciseCreateView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: ((Exercise) -> Void)?
    
    @StateObject private var vm: ExerciseCreateViewModel
    
    init(example: Example, lesson: Lesson?, word: Word?, onCreated: ((Exercise) -> Void)? = nil) {
        self.onCreated = onCreated
        let vm = ExerciseCreateViewModel(example: example, lesson: lesson, word: word)
        _vm = StateObject(wrappedValue: vm)
    }

    private let exerciseTypes: [ExerciseType] = ExerciseType.allCases
    
    // MARK: - View
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(vm.example.text)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .help("닫기")
                    }
                    Text(vm.translation)
                    Text(vm.word?.text ?? "")
                }
            }

            contentView()

            // 제출
            Section {
                Button {
                    Task { await vm.submit() }
                } label: {
                    if vm.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Create Exercise")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!vm.canSubmit)
            }

            // 결과/에러
            if let created = vm.createdExercise {
                Section(header: Text("Created")) {
                    Text("ID: \(created.id)")
                    Text("Type: \(created.type)")
                    Text("Words: \(created.wordOptions)")
                }
            }

            if let error = vm.errorMessage {
                Section(header: Text("Error")) {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("New Exercise")
    }
}

extension ExerciseCreateView {
    private var combineCreatorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("옵션")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(vm.words.joined(separator: ","))
                .font(.body)
        }
    }
    
    private var selectCreatorView: some View {
        VStack(alignment: .leading, spacing: 12) {

            let allWords = vm.allWords

            if allWords.isEmpty {
                Text("단어가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                // 칩 레이아웃
                let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(allWords, id: \.self) { word in
                        Button {
                            vm.selectedWord = word
                        } label: {
                            HStack(spacing: 6) {
                                if vm.selectedWord == word {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(word)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(vm.selectedWord == word ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(vm.selectedWord == word ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("'\(word)' 선택")
                    }
                }
            }

            // 선택 상태 표시
            if let selected = vm.selectedWord {
                Text("선택된 단어: \(selected)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            let extra = vm.wordsLearned.map { $0.text }.filter { $0 != vm.selectedWord }
            let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(extra, id: \.self) { word in
                    Button {
                        if vm.dummyWords.contains(word) {
                            vm.dummyWords.removeAll(where: { $0 == word })
                        } else {
                            vm.dummyWords.append(word)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.dummyWords.contains(word) {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(word)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(vm.dummyWords.contains(word) ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(vm.dummyWords.contains(word) ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("'\(word)' 선택")
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("옵션")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vm.words.joined(separator: ","))
                    .font(.body)
            }
        }
    }
    
    private var selectTransCreatorView: some View {
        VStack(alignment: .leading, spacing: 12) {

            let allWords = vm.allWords

            if allWords.isEmpty {
                Text("단어가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                // 칩 레이아웃
                let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(allWords, id: \.self) { word in
                        Button {
                            vm.selectedWord = word
                        } label: {
                            HStack(spacing: 6) {
                                if vm.selectedWord == word {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(word)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(vm.selectedWord == word ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(vm.selectedWord == word ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("'\(word)' 선택")
                    }
                }
            }

            // 선택 상태 표시
            if let selected = vm.selectedWord {
                Text("선택된 단어: \(selected)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            let extra = vm.wordsLearned.map { $0.text }.filter { $0 != vm.selectedWord }
            let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(extra, id: \.self) { word in
                    Button {
                        if vm.dummyWords.contains(word) {
                            vm.dummyWords.removeAll(where: { $0 == word })
                        } else {
                            vm.dummyWords.append(word)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.dummyWords.contains(word) {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(word)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(vm.dummyWords.contains(word) ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(vm.dummyWords.contains(word) ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("'\(word)' 선택")
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("옵션")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vm.words.joined(separator: ","))
                    .font(.body)
            }
        }
    }

    
    private var inputCreatorView: some View {
        Button {
            
        } label: {
            Label("보기 추가", systemImage: "plus.circle")
        }
        .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private func contentView() -> some View {
        // 공통 섹션
        Section() {
            Picker("Type", selection: $vm.type) {
                ForEach(exerciseTypes, id: \.self) { t in
                    Text(t.name).tag(t)   // vm.type은 String(rawValue)
                }
            }
        }
        
        Section() {
            Text("\(vm.content)")
        }
        
        // 타입별 입력/자동생성
        if vm.type == .select {
            Section() {
                selectCreatorView
            }
        } else if vm.type == .combine {
            // 자동 생성 미리보기 (편집 불가)
            Section() {
                combineCreatorView
            }
        } else if vm.type == .input {
            Section() {
                inputCreatorView
            }
        }
    }
}
