//
//  PronounciationView.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import SwiftUI

struct PronounciationView: View {
    @StateObject private var vm = PronounciationViewModel()

    var body: some View {
        VStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Pronunciation Bulk Input")
                    .font(.headline)

                TextEditor(text: $vm.inputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack(spacing: 10) {
                Button {
                    vm.parseInput()
                } label: {
                    Label("Parse", systemImage: "text.magnifyingglass")
                }
                .disabled(vm.isParsing || vm.isResolving || vm.isCreating)

                Button {
                    Task { await vm.resolveWords() }
                } label: {
                    Label("Resolve words", systemImage: "link")
                }
                .disabled(vm.isResolving || vm.isCreating)

                Spacer()

                Button(role: .none) {
                    Task { await vm.createPronunciations() }
                } label: {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isCreating)
            }

            if let msg = vm.message {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Preview (\(vm.items.count))")
                        .font(.headline)
                    Spacer()

                    if vm.isResolving || vm.isCreating {
                        ProgressView()
                            .scaleEffect(0.9)
                    }
                }

                if vm.items.isEmpty {
                    Text("아직 항목이 없어요. Parse를 눌러주세요.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    List(vm.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.wordText)
                                    .font(.headline)
                                Spacer()
                                Text(item.pos)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.ipa)
                                .font(.system(.body, design: .monospaced))

                            HStack(spacing: 12) {
                                Text("wordId: \(item.wordId.map(String.init) ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("senseId: \(item.senseId.map(String.init) ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("dialect: US")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Pronunciations")
    }
}
