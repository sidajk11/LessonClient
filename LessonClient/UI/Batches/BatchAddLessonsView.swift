import SwiftUI

struct BatchAddLessonsView: View {
    @StateObject private var vm = BatchAddLessonsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("시작 unit", text: $vm.startUnitText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: vm.startUnitText) { _, newValue in
                        vm.sanitizeStartUnit(newValue)
                    }

                TextField("토픽", text: $vm.topicText)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text("vocabulary들 (`vocabulary^ko번역`)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $vm.vocabularyListText)
                        .frame(minHeight: 220)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        }

                    Text("예시:\nourselves^우리 자신\nintroduce^소개하다\nmyself^나 자신")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("입력한 vocabulary를 2개씩 묶어서 `start_unit`, `start_unit + 1` 순서로 레슨에 추가합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("총 vocabulary \(vm.parsedVocabularies.count)개 / 생성 대상 레슨 \(vm.lessonCount)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await vm.addLessons() }
                } label: {
                    if vm.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("레슨 추가")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canSave)

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
        .navigationTitle("레슨 추가")
    }
}
