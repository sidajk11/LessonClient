//
//  FormEditorSheet.swift
//  LessonClient
//
//  Created by ym on 2/20/26.
//

import SwiftUI

struct FormEditorSheet: View {
    let wordId: Int
    let editing: WordFormRead?
    let onCancel: () -> Void
    let onSave: (String, String?) -> Void

    @State private var form: String = ""
    @State private var formType: String = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(editing == nil ? "New Form" : "Edit Form")
                    .font(.title3)
                    .bold()
                Spacer()
            }

            Form {
                Section("Target") {
                    HStack {
                        Text("word_id")
                        Spacer()
                        Text("\(wordId)").foregroundStyle(.secondary)
                    }
                }

                Section("Form") {
                    TextField("form", text: $form)
                        .autocorrectionDisabled()
                }

                Section("Type (optional)") {
                    TextField("form_type", text: $formType)
                        .autocorrectionDisabled()
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    let f = form.trimmingCharacters(in: .whitespacesAndNewlines)
                    let ft = formType.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(f, ft.isEmpty ? nil : ft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(form.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || wordId <= 0)
            }
        }
        .padding(16)
        .onAppear {
            if let editing {
                form = editing.form
                formType = editing.formType ?? ""
            }
        }
    }
}
