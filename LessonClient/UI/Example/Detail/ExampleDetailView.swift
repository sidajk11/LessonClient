// ExampleDetailView.swift

import SwiftUI

struct ExampleDetailView: View {
    @StateObject private var vm: ExampleDetailViewModel

    init(exampleId: Int, lesson: Lesson?, word: Vocabulary?) {
        _vm = StateObject(wrappedValue: ExampleDetailViewModel(exampleId: exampleId, lesson: lesson, word: word))
    }

    var body: some View {
        Form {
            Section(header: Text("연습문제")) {
                NavigationLink("연습문제들") {
                    if let example = vm.example {
                        ExerciseListView(example: example)
                    }
                }
            }
            Section("문장") {
                TextField("영어 문장", text: $vm.sentence)
                    .autocorrectionDisabled()
            }
            Section("번역들") {
                Text("한 줄에 하나씩 입력하세요.\n예)\nko: 내 가방과 내 휴대폰.\nes: Mi bolsa y mi teléfono.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $vm.translationText)
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }
            Section("토큰") {
                if let tokens = vm.example?.tokens, !tokens.isEmpty {
                    let translationTargets = tokens.filter { !punctuationSet.contains($0.surface) }
                    let hasAnyTokenTranslation = translationTargets.contains { !$0.translations.isEmpty }

                    HStack {
                        Button {
                            Task { await vm.recreateTokensFromSentence() }
                        } label: {
                            if vm.isRecreatingTokens {
                                ProgressView()
                            } else {
                                Text("토큰 재생성")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isRecreatingTokens)

                        Button {
                            Task { await vm.copyTokenSummary() }
                        } label: {
                            if vm.isCopyingTokenSummary {
                                ProgressView()
                            } else {
                                Text("전체 복사")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isCopyingTokenSummary || vm.isDeletingTokens)

                        Button("번역 할 토큰 복사") {
                            vm.copyTokenTranslationSummary()
                        }
                        .buttonStyle(.bordered)

                        Button("sense추가") {
                            vm.openSenseAssignSheet()
                        }
                        .buttonStyle(.bordered)

                        Button(hasAnyTokenTranslation ? "번역수정" : "번역추가") {
                            vm.openTokenTranslationSheet()
                        }
                        .buttonStyle(.bordered)
                        
                        Button(role: .destructive) {
                            Task { await vm.deleteAllTokens() }
                        } label: {
                            if vm.isDeletingTokens {
                                ProgressView()
                            } else {
                                Text("토큰삭제")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isDeletingTokens || vm.isRecreatingTokens)
                        
                        Spacer()
                    }

                    ForEach(tokens.sorted(by: { $0.tokenIndex < $1.tokenIndex })) { token in
                        NavigationLink {
                            SentenceTokenDetailView(tokenId: token.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(token.tokenIndex). \(token.surface)")
                                    .font(.body)
                                Text("tokenId:\(token.id) phrase:\(token.phraseId.map(String.init) ?? "-") word:\(token.wordId.map(String.init) ?? "-") form:\(token.formId.map(String.init) ?? "-") sense:\(token.senseId.map(String.init) ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let ko = vm.tokenKoreanById[token.id], !ko.isEmpty {
                                    Text("ko: \(ko)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                let tokenKoTranslation = token.translations.first(where: {
                                    let lang = $0.lang.lowercased()
                                    return lang == "ko" || lang.hasPrefix("ko-")
                                })?.text ?? "-"
                                Text("문장에서 번역: \(tokenKoTranslation)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("토큰이 없습니다.")
                            .foregroundStyle(.secondary)

                        Button {
                            Task { await vm.createTokensFromSentence() }
                        } label: {
                            if vm.isCreatingTokens {
                                ProgressView()
                            } else {
                                Text("토큰 생성")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isCreatingTokens || vm.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            Button {
                Task { await vm.save() }
            } label: {
                if vm.isSaving { ProgressView() } else { Text("저장") }
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("예문 상세")
        .task { await vm.load() }
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
//        .alert("완료", isPresented: .constant(vm.info != nil)) {
//            Button("확인") { vm.info = nil }
//        } message: { Text(vm.info ?? "") }
        .sheet(isPresented: $vm.isShowingSenseAssignSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("token_id / sense_id 입력")
                    .font(.headline)

                TextEditor(text: $vm.senseAssignText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 280)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                HStack {
                    Spacer()
                    Button("취소") {
                        vm.isShowingSenseAssignSheet = false
                    }
                    .disabled(vm.isApplyingSenseAssign)

                    Button {
                        Task { await vm.applySenseAssignments() }
                    } label: {
                        if vm.isApplyingSenseAssign {
                            ProgressView()
                        } else {
                            Text("적용")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isApplyingSenseAssign)
                }
            }
            .padding(16)
            .frame(minWidth: 520, minHeight: 380)
        }
        .sheet(isPresented: $vm.isShowingTokenTranslationSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("토큰 번역 입력")
                    .font(.headline)

                TextEditor(text: $vm.tokenTranslationText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 320)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                HStack {
                    Spacer()
                    Button("취소") {
                        vm.isShowingTokenTranslationSheet = false
                    }
                    .disabled(vm.isApplyingTokenTranslations)

                    Button {
                        Task { await vm.applyTokenTranslations() }
                    } label: {
                        if vm.isApplyingTokenTranslations {
                            ProgressView()
                        } else {
                            Text("적용")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isApplyingTokenTranslations)
                }
            }
            .padding(16)
            .frame(minWidth: 560, minHeight: 420)
        }
    }
}
