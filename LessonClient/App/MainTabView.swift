// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        TabView {
            LessonListView().tabItem { Text("레슨") }
            VocabularyListView().tabItem { Text("학습 단어") }
            ExamplesSearchView().tabItem { Text("예문") }
            PracticeSearchView().tabItem { Text("연습문제") }
            WordListView().tabItem { Text("사전 단어") }
            CambridgeWebView().tabItem { Text("Cambridge") }
        }
        .toolbar {
            Button("로그아웃") { app.logout() }
        }
    }
}
