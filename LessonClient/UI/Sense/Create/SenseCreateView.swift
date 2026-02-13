//
//  SenseCreateView.swift
//  LessonClient
//
//  Created by ym on 2/12/26.
//

import SwiftUI

struct SenseCreateView: View {
    @StateObject private var vm = SenseCreateViewModel()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Sense Create")
                    .font(.headline)
                Spacer()
                if vm.isSaving {
                    ProgressView()
                        .scaleEffect(0.9)
                }
            }

            TextEditor(text: $vm.rawText)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 260)

            if let preview = vm.previewHead {
                HStack {
                    Text("단어: \(preview)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("감지된 sense: \(vm.previewSenseCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let msg = vm.statusMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(vm.isError ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await vm.save() }
            } label: {
                Text("저장")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isSaving || vm.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .onChange(of: vm.rawText) { _, _ in
            vm.refreshPreview()
        }
        .onAppear {
            // 예시 텍스트를 기본으로 넣고 싶으면 주석 해제
            /*
            vm.rawText = """
            phone

            sense: a device used to talk to someone who is in another place
            pos: noun
            cefr: A1
            ko: 전화기
            example: She answered the phone quickly.

            sense: a smartphone
            pos: noun
            cefr: A1
            ko: 휴대전화, 스마트폰
            example: I left my phone at home.

            sense: to call someone using a phone
            pos: verb
            cefr: A2
            ko: 전화하다
            example: I’ll phone you later.
            """
            vm.refreshPreview()
            */
        }
        .safeAreaInset(edge: .bottom) {
            if let msg = vm.statusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: vm.isError ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundStyle(vm.isError ? .red : .secondary)
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(vm.isError ? .red : .secondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)
            }
        }
    }
}
