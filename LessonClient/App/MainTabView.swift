// MainTabView.swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        TabView {
            LessonListView().tabItem { Text("레슨") }
            VocabularyListView().tabItem { Text("학습 단어") }
            ExamplesSearchView().tabItem { Text("예문") }
            ExerciseSearchView().tabItem { Text("연습문제") }
            ExerciseAttemptListView().tabItem { Text("시도 기록") }
            ExerciseQueueListView().tabItem { Text("학습 큐") }
            UserLessonTargetStateListView().tabItem { Text("목표 상태") }
            WordListView().tabItem { Text("사전 단어") }
            CambridgeWebView().tabItem { Text("Cambridge") }
            FormListView().tabItem { Text("포럼") }
            PhraseListView().tabItem { Text("구문") }
            PronounciationListView().tabItem { Text("발음법") }
            TTSView().tabItem { Text("TTS") }
        }
        .toolbar {
            Button("로그아웃") { app.logout() }
        }
    }
}

@MainActor
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let app = AppState()
        app.user = User(id: 1, email: "preview@example.com")
        return HomeView()
            .environmentObject(app)
    }
}
