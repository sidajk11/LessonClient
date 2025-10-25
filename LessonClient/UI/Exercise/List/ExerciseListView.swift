//
//  ExerciseListView.swift
//  LessonClient
//
//  Created by 정영민 on 10/14/25.
//

import SwiftUI
import Combine

// MARK: - Exercise List View
struct ExerciseListView: View {
    @StateObject private var vm: ExerciseListViewModel
    @State private var showingCreate: Bool = false

    init(example: Example) {
        _vm = StateObject(wrappedValue: ExerciseListViewModel(example: example))
    }

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section(header: Text("오류")) {
                    Text(error).foregroundStyle(.red)
                }
            }

            if vm.isLoading && vm.exercises.isEmpty {
                Section {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }

            Section(header: Text("연습문제 목록")) {
                if vm.exercises.isEmpty && !vm.isLoading && vm.errorMessage == nil {
                    Text("등록된 연습문제가 없습니다.")
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.exercises, id: \.id) { ex in
                    NavigationLink {
                        ExerciseDetailView(exercise: ex)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(ex.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(ex.type)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
                            }
                            Text(ex.wordOptions.enText())
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
        .sheet(isPresented: $showingCreate) {
            NavigationStack { // keep navigation chrome consistent
                ExerciseCreateView(example: vm.example, lesson: nil, word: vm.word) { _ in
                        // 선택: 생성 후 리스트 새로고침
                        Task { await vm.load() }
                    }
                    .padding()
                    .frame(minWidth: 520, minHeight: 460)
            }
        }
    }
}
