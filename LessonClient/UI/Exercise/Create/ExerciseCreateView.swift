import SwiftUI
import Combine

struct ExerciseCreateView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: ((Exercise) -> Void)?
    
    @StateObject private var vm: ExerciseCreateViewModel
    
    init(example: Example, onCreated: ((Exercise) -> Void)? = nil) {
        self.onCreated = onCreated
        let vm = ExerciseCreateViewModel(example: example)
        _vm = StateObject(wrappedValue: vm)
    }

    private let exerciseTypes: [ExerciseType] = ExerciseType.allCases
    
    // MARK: - View
    var body: some View {
        Form {
            
            Section {
                Text(vm.example.text)
            }
            
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
        .toolbar {
            // macOS: 툴바에 X 아이콘 + ⌘W
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .help("닫기")
                .keyboardShortcut("w", modifiers: [.command]) // ⌘W로 닫기
            }
        }
        // 제출 중에는 실수로 닫히지 않게(원하면)
        .interactiveDismissDisabled(vm.isSubmitting)
    }
}
