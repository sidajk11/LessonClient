// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        TabView {
            LessonsScreen().tabItem { Text("레슨") }
            WordsScreen().tabItem { Text("단어") }
            ExamplesSearchScreen().tabItem { Text("예문") }
            ExpressionScreen().tabItem { Text("표현") }
        }
        .toolbar {
            Button("로그아웃") { app.logout() }
        }
    }
}
