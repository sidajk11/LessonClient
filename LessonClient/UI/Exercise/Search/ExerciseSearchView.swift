//
//  ExerciseSearchView.swift
//  LessonClient
//
//  Created by ymj on 10/14/25.
//

import SwiftUI

struct ExerciseSearchView: View {
    @StateObject private var vm = ExerciseSearchViewModel()

    var body: some View {
        VStack(spacing: 8) {
            // 검색 바
            HStack(spacing: 8) {
                TextField("연습문제 검색 (문항/예문/번역/선택지)", text: $vm.q)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await vm.search() } }

                TextField("레벨 (선택)", text: $vm.levelText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    .onChange(of: vm.levelText) { _, newValue in vm.sanitizeLevel(newValue) }
                    .onSubmit { Task { await vm.search() } }

                TextField("Unit (선택)", text: $vm.unitText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    .onChange(of: vm.unitText) { _, newValue in vm.sanitizeUnit(newValue) }
                    .onSubmit { Task { await vm.search() } }

                Button("검색") { Task { await vm.search() } }
                Button("검사") { vm.validateAll() }
            }
            .padding(.horizontal)

            if vm.isLoading && vm.items.isEmpty {
                ProgressView().padding(.top, 8)
            }

            // 결과 리스트
            List(vm.items) { ex in
                NavigationLink {
                    ExerciseSearchDetailLoaderView(exercise: ex)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        // 1) 상단: 타입 / 정답
                        HStack {
                            Text(ex.type.name)
                                .font(.headline)
                            Spacer()
                            Text("Vocabularys: \(ex.options.map { $0.displayText }.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // 3) 예문 정보
                        Text("예문 ID: \(ex.exampleId.map(String.init) ?? "-")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        if let prompt = ex.prompt, !prompt.isEmpty {
                            Text(prompt)
                                .font(.subheadline)
                        }

                        if let validationError = vm.validationErrors[ex.id] {
                            Text(validationError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("연습문제 검색")
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}

private struct ExerciseSearchDetailLoaderView: View {
    let exercise: Exercise

    @State private var example: Example?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let example {
                ExerciseDetailView(example: example, practice: exercise)
            } else if let errorMessage {
                ContentUnavailableView("상세를 불러오지 못했습니다.", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView("불러오는 중…")
            }
        }
        .task {
            guard example == nil, errorMessage == nil else { return }
            guard let exampleId = exercise.exampleId else {
                errorMessage = "예문 ID가 없습니다."
                return
            }

            do {
                // 상세 화면 진입 전에 필요한 예문을 조회합니다.
                example = try await ExampleDataSource.shared.example(id: exampleId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
