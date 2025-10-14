// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        TabView {
            LessonListView().tabItem { Text("레슨") }
            WordListView().tabItem { Text("단어") }
            ExamplesSearchView().tabItem { Text("예문") }
            ExerciseSearchView().tabItem { Text("연습문제") }
        }
        .toolbar {
            Button("로그아웃") { app.logout() }
        }
    }
}
