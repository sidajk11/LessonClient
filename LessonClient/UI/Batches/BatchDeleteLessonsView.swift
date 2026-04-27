import SwiftUI

struct BatchDeleteLessonsView: View {
    @StateObject private var vm = BatchDeleteLessonsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("시작 unit", text: $vm.startUnitText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: vm.startUnitText) { _, newValue in
                        vm.sanitizeStartUnit(newValue)
                    }

                TextField("끝 unit", text: $vm.endUnitText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: vm.endUnitText) { _, newValue in
                        vm.sanitizeEndUnit(newValue)
                    }

                Text("입력한 시작 unit부터 끝 unit까지, 양 끝 포함해서 해당 레슨을 모두 삭제합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    Task { await vm.deleteLessons() }
                } label: {
                    if vm.isDeleting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("레슨 삭제")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canDelete)

                if let progressText = vm.progressText, !progressText.isEmpty {
                    Text(progressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if !vm.resultText.isEmpty {
                    Text(vm.resultText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle("레슨 삭제")
    }
}
