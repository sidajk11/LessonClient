// LessonClientApp.swift
import SwiftUI

@main
struct LessonClientApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task { await appState.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        if app.loading {
            ProgressView("로딩 중…").padding()
        } else if app.user == nil {
            LoginView()
        } else {
            MainTabView()
        }
    }
}
