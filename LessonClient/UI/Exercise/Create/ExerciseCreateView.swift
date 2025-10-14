// MARK: - Exercise Create View (SwiftUI)

import SwiftUI
import Combine

struct ExerciseCreateView: View {
    let exampleId: Int
    @StateObject private var vm: ExerciseCreateViewModel

    init(exampleId: Int) {
        self.exampleId = exampleId
        _vm = StateObject(wrappedValue: ExerciseCreateViewModel(exampleId: exampleId))
    }

    private let exerciseTypes: [String] = ["fill", "choice", "translate", "spell"]

    var body: some View {
        Form {
            Section(header: Text("Exercise Info")) {
                Picker("Type", selection: $vm.type) {
                    ForEach(exerciseTypes, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }

                TextField("Answer", text: $vm.answer)
                    .autocorrectionDisabled()
            }

            Section() {
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

            if let created = vm.createdExercise {
                Section(header: Text("Created")) {
                    Text("ID: \(created.id)")
                    Text("Type: \(created.type)")
                    Text("Answer: \(created.answer)")
                }
            }

            if let error = vm.errorMessage {
                Section(header: Text("Error")) {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("New Exercise")
    }
}
