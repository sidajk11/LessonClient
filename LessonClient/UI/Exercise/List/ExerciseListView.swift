//
//  ExerciseListView.swift
//  LessonClient
//
//  Created by 정영민 on 10/14/25.
//

import SwiftUI
import Combine

// MARK: - Practice List View
struct ExerciseListView: View {
    @StateObject private var vm: ExerciseListViewModel
    @State private var showingCreate: Bool = false

    init(example: Example, exampleSentence: ExampleSentence? = nil, usePrefetchedExercisesOnly: Bool = false) {
        _vm = StateObject(wrappedValue: ExerciseListViewModel(example: example, exampleSentence: exampleSentence, usePrefetchedExercisesOnly: usePrefetchedExercisesOnly))
    }

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section(header: Text("오류")) {
                    Text(error).foregroundStyle(.red)
                }
            }

            if vm.isLoading && vm.practices.isEmpty {
                Section {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }

            Section(header: Text("연습문제 목록")) {
                if vm.practices.isEmpty && !vm.isLoading && vm.errorMessage == nil {
                    Text("등록된 연습문제가 없습니다.")
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.practices, id: \.id) { ex in
                    NavigationLink {
                        ExerciseDetailView(example: vm.example, practice: ex)
                            .onDisappear {
                                Task {
                                    await vm.load()
                                }
                            }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(ex.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(vm.exampleSentence?.text ?? "")
                                Spacer()
                                Text(ex.prompt ?? "")
                                Spacer()
                                Text(ex.type.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
                            }
                            Text(ex.options.map { $0.displayText }.joined(separator: ", "))
                                .font(.body)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("연습문제들")
        .task { await vm.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("연습문제 추가")
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .sheet(isPresented: $showingCreate, onDismiss: {
            Task { await vm.load() }
        }) {
            NavigationStack { // keep navigation chrome consistent
                if let exampleSentence = vm.exampleSentence {
                    ExerciseCreateView(
                        exampleSentence: exampleSentence,
                        exampleId: vm.example.id,
                        vocabularyId: vm.example.vocabularyId,
                        lesson: nil,
                        word: vm.word
                    ) { _ in
                        // 선택: 생성 후 리스트 새로고침
                        Task { await vm.load() }
                    }
                    .padding()
                    .frame(minWidth: 520, minHeight: 460)
                } else {
                    ContentUnavailableView("ExampleSentence 없음", systemImage: "exclamationmark.triangle")
                        .frame(minWidth: 520, minHeight: 460)
                }
            }
        }
    }
}
