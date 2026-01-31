//
//  PracticeSearchView.swift
//  LessonClient
//
//  Created by ymj on 10/14/25.
//

import SwiftUI

struct PracticeSearchView: View {
    @StateObject private var vm = PracticeSearchViewModel()

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
                    .onChange(of: vm.levelText) { vm.sanitizeLevel($0) }
                    .onSubmit { Task { await vm.search() } }

                TextField("Unit (선택)", text: $vm.unitText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    .onChange(of: vm.unitText) { vm.sanitizeUnit($0) }
                    .onSubmit { Task { await vm.search() } }

                Button("검색") { Task { await vm.search() } }
            }
            .padding(.horizontal)

            if vm.isLoading && vm.items.isEmpty {
                ProgressView().padding(.top, 8)
            }

            // 결과 리스트
            List(vm.items) { ex in
                VStack(alignment: .leading, spacing: 6) {
                    // 1) 상단: 타입 / 정답
                    HStack {
                        Text(ex.type.name)
                            .font(.headline)
                        Spacer()
                        Text("Vocabularys: \(ex.options)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // 3) 예문 정보
                    Text("예문 ID: \(ex.exampleId)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("연습문제 검색")
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}
