import SwiftUI
import Combine

struct ExerciseCreateView: View {
    let exampleId: Int
    let sentence: String
    let wordText: String
    @StateObject private var vm: ExerciseCreateViewModel
    @State private var content: String = ""

    init(exampleId: Int, sentence: String, wordText: String) {
        self.exampleId = exampleId
        self.sentence = sentence
        self.wordText = wordText
        let vm = ExerciseCreateViewModel(exampleId: exampleId, sentence: sentence, wordText: wordText)
        _vm = StateObject(wrappedValue: vm)
    }

    private let exerciseTypes: [ExerciseType] = ExerciseType.allCases
    
    // MARK: - View
    var body: some View {
        Form {
            // 공통 섹션
            Section(header: Text("Exercise Info")) {
                Picker("Type", selection: $vm.type) {
                    ForEach(exerciseTypes, id: \.self) { t in
                        Text(t.name).tag(t.rawValue)   // vm.type은 String(rawValue)
                    }
                }
            }

            // 타입별 입력/자동생성
            if vm.type == .select {
                Section(header: Text("보기 (Options)")) {

                    Button {
                        
                    } label: {
                        Label("보기 추가", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
            } else if vm.type == .combine {
                // 자동 생성 미리보기 (편집 불가)
                Section(header: Text("자동 생성 (읽기 전용)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("옵션")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(vm.words.joined(separator: ","))
                            .font(.body)
                    }
                }
            }

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
                    Text("Words: \(created.words)")
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
