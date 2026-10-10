import SwiftUI

struct LessonInsertView: View {
    @Environment(\.dismiss) private var dismiss
    let onInserted: (() -> Void)?

    @StateObject private var viewModel = LessonInsertViewModel()

    init(onInserted: (() -> Void)? = nil) {
        self.onInserted = onInserted
    }

    var body: some View {
        Form {
            Section {
                TextField("Unit", text: $viewModel.unitText)
                    .onChange(of: viewModel.unitText) { _, newValue in
                        viewModel.unitText = newValue.filter(\.isNumber)
                    }

                TextField("트랙 코드", text: $viewModel.trackCode)
            } header: {
                Text("삽입 위치")
            } footer: {
                Text("지정한 unit부터 같은 트랙의 모든 레슨이 한 칸 뒤로 이동합니다.")
            }

            Section("기본 정보") {
                TextField("토픽", text: $viewModel.topic)
                TextField("문법", text: $viewModel.grammar)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    do {
                        _ = try await viewModel.insertLesson()
                        onInserted?()
                        dismiss()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text("레슨 삽입")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canInsert)
        }
        .navigationTitle("레슨 삽입")
        .frame(minWidth: 420)
    }
}
