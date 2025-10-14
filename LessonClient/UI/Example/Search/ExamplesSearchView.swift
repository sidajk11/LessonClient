//
//  ExamplesSearchView.swift
//  LessonClient
//
//  Created by 정영민 on 8/28/25.
//  MVVM refactor on 10/13/25
//

import SwiftUI

struct ExamplesSearchView: View {
    @StateObject private var vm = ExamplesSearchViewModel()

    var body: some View {
        VStack(spacing: 8) {
            // 검색 바
            HStack(spacing: 8) {
                TextField("예문 검색", text: $vm.q)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await vm.search() } }

                TextField("레벨 코드 (예: 1, A1)", text: $vm.levelCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                    .onSubmit { Task { await vm.search() } }

                TextField("Unit (선택)", text: $vm.unitText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 110)
                    .onChange(of: vm.unitText) { newValue in
                        vm.sanitizeUnitInput(newValue)
                    }

                TextField("언어 (예: ko)", text: $vm.lang)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 90)
                    .onSubmit { Task { await vm.search() } }

                Button("검색") { Task { await vm.search() } }
            }
            .padding(.horizontal)

            if vm.isLoading && vm.items.isEmpty {
                ProgressView().padding(.top, 8)
            }

            // 결과 리스트
            List(vm.items) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.text)
                        .font(.body)

                    Text(row.translationsText())

                    Text("단어: \(row.wordText ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("예문")
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}
