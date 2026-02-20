//
//  FormCreateView.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import SwiftUI

struct FormCreateView: View {
    @StateObject private var vm = FormCreateViewModel()
    
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 12) {

            // Top bar
            HStack {
                Text("Form Create")
                    .font(.title2)
                    .bold()

                Spacer()

                if vm.isParsing {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Parsing…")
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Save") {
                    Task {
                        await vm.saveAll()
                        // 하나라도 성공했으면 종료
                        if vm.rows.contains(where: {
                            if case .saved = $0.status { return true }
                            return false
                        }) {
                            onFinished()
                        }
                    }
                }
                .disabled(vm.rows.isEmpty || vm.isSaving)
                .keyboardShortcut(.defaultAction)

                Button("Clear") { vm.clearAll() }
                    .disabled(vm.isSaving)
            }

            // Error banner
            if let msg = vm.statusMessage, !msg.isEmpty {
                HStack {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary) // 에러만 빨강으로 하고 싶으면 status에 따라 분기 가능
                    Spacer()
                }
                .padding(8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Input + Preview
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input")
                        .font(.headline)

                    TextEditor(text: $vm.rawText)
                        .font(.system(.body, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.separator, lineWidth: 1)
                        )
                }
                .frame(minWidth: 380)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Preview")
                            .font(.headline)
                        Spacer()
                        if vm.isSaving {
                            ProgressView().controlSize(.small)
                        }
                    }

                    Table(vm.rows) {
                        TableColumn("Word") { row in
                            Text(row.word)
                        }
                        .width(min: 90, ideal: 120)

                        TableColumn("Form") { row in
                            Text(row.form)
                        }
                        .width(min: 90, ideal: 120)

                        TableColumn("Form Type") { row in
                            Text(row.formType ?? "")
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 160, ideal: 220)

                        TableColumn("Explain (ko)") { row in
                            Text(row.explainKo ?? "")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .width(min: 240, ideal: 360)

                        TableColumn("Status") { row in
                            statusView(row.status)
                        }
                        .width(min: 120, ideal: 160)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.separator, lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .onAppear {
            // 예시 텍스트(원하면 지워도 됨)
            if vm.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.rawText =
"""
word: be
form: am
form_type: present_singular_1st
explain: 1인칭 단수 현재형 (I am) – 나는 …이다/있다

word: be
form: is
form_type: present_singular_3rd
explain: 3인칭 단수 현재형 (he/she/it is) – 그는/그녀는/그것은 …이다/있다
"""
            }
        }
        .frame(minWidth: 1050, minHeight: 560)
    }

    @ViewBuilder
    private func statusView(_ status: FormCreateViewModel.DraftRow.Status) -> some View {
        switch status {
        case .ready:
            Text("Ready").foregroundStyle(.secondary)
        case .saving:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Saving…")
            }
        case .saved(let formId):
            Text("Saved (#\(formId))")
        case .failed(let message):
            Text("Failed")
                .foregroundStyle(.red)
                .help(message) // hover 시 에러 메시지
        case .skipped(reason: let reason):
            Text("Skipped (#\(reason))")
        }
    }
}
