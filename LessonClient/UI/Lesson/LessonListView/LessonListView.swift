//
//  LessonListView.swift
//  LessonClient
//
//  Created by ymj on 9/5/25.
//  MVVM refactor on 10/13/25
//

import SwiftUI
import AppKit

struct LessonListView: View {
    @StateObject private var vm = LessonListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {

                // ===== 필터/액션 줄 =====
                HStack(spacing: 8) {
                    TextField("레벨", text: $vm.levelText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: vm.levelText) { vm.levelText = $0.filter(\.isNumber) }
                        .onSubmit { Task { await vm.search() } }

                    Button("검색") { Task { await vm.search() } }
                        .buttonStyle(.borderedProminent)

                    Button("초기화") {
                        Task { await vm.reset() }
                    }

                    Button {
                        Task { await vm.copyLessons() }
                    } label: {
                        if vm.isCopying {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("복사")
                        }
                    }
                    .disabled(vm.isCopying)
                }
                .padding(.horizontal)

                // ===== 목록 =====
                ZStack(alignment: .bottomTrailing) {
                    List(vm.items) { l in
                        NavigationLink {
                            LessonDetailView(lessonId: l.id)
                        } label: {
                            LessonRowView(lesson: l)
                        }
                        .badge("\(l.translations.koText())")
                    }
                    .task { await vm.load() }

                    // ===== 플로팅 버튼들 =====
                    VStack(spacing: 12) {
                        NavigationLink {
                            LessonCreateView { newLesson in
                                // Insert at top after create
                                vm.items.insert(newLesson, at: 0)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("레슨")
        }
        .alert("오류", isPresented: .constant(vm.error != nil)) {
            Button("확인") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .alert("복사 완료", isPresented: .constant(vm.copyInfo != nil)) {
            Button("OK") { vm.copyInfo = nil }
        } message: { Text(vm.copyInfo ?? "") }
    }
}
