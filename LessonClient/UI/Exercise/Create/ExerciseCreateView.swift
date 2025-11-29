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
        ScrollView {
            form
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var form: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(vm.example.text)
                    }
                    Text(vm.translation)
                    Text(vm.word?.text ?? "")
                }
                Button {
                    Task {
                        await vm.autoGenerate()
                        dismiss()
                    }
                } label: {
                    Text("자동생성")
                }
            }

            contentView()

            // 제출
            Section {
                VStack {
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
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .help("닫기")
                }
            }

            // 결과/에러
            if let created = vm.createdExercise {
                Section(header: Text("Created")) {
                    Text(verbatim: "ID: \(created.id)")
                    Text(verbatim: "Type: \(created.type.rawValue)")
                    if created.type == .combine {
                        Text(verbatim: "Words: \(created.wordOptions.text(langCode: .enUS))")
                    }
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
            Text(vm.wordOptionTextList.joined(separator: ","))
                .font(.body)
        }
    }
    
    private var selectCreatorView: some View {
        VStack(alignment: .leading, spacing: 12) {

            let allWordsInSentence = vm.allWordsInSentence

            if allWordsInSentence.isEmpty {
                Text("단어가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                // 칩 레이아웃
                let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(allWordsInSentence.indices, id: \.self) { index in
                        let word = allWordsInSentence[index]
                        Button {
                            vm.selectTestWord(index: index)
                        } label: {
                            HStack(spacing: 6) {
                                if vm.isTestWordSelected(index: index) {
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
                                    .fill(vm.isTestWordSelected(index: index) ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(vm.isTestWordSelected(index: index) ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("'\(word)' 선택")
                    }
                }
            }

            // 선택 상태 표시
            Text("선택된 단어: \(vm.selectedTestWords.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            let extra = vm.selectableDummyWords()
            let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(extra, id: \.self) { word in
                    Button {
                        vm.selectDummyWord(word: word)
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isDummyWordSelected(word: word) {
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
                                .fill(vm.isDummyWordSelected(word: word) ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(vm.isDummyWordSelected(word: word) ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
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
                Text(vm.wordOptionTextList.joined(separator: ","))
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
