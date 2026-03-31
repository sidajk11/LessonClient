// MainTabView.swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedTab: Tab = .lesson

    private enum Tab: String, CaseIterable, Identifiable {
        case lesson
        case vocabulary
        case examples
        case exampleSentence
        case exercise
        case exerciseAttempt
        case exerciseQueue
        case userVocabularyState
        case word
        case cambridge
        case form
        case phrase
        case pronunciation
        case tts
        case sense

        var id: Self { self }

        var title: String {
            switch self {
            case .lesson: "레슨"
            case .vocabulary: "학습 단어"
            case .examples: "예문"
            case .exampleSentence: "예문 문장"
            case .exercise: "연습문제"
            case .exerciseAttempt: "시도 기록"
            case .exerciseQueue: "학습 큐"
            case .userVocabularyState: "단어 상태"
            case .word: "사전 단어"
            case .cambridge: "Cambridge"
            case .form: "포럼"
            case .phrase: "구문"
            case .pronunciation: "발음법"
            case .tts: "TTS"
            case .sense: "Sense"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Tab.allCases) { tab in
                        Button(tab.title) {
                            selectedTab = tab
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.16) : Color.clear)
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            Divider()

            TabView(selection: $selectedTab) {
                LessonListView().tag(Tab.lesson)
                VocabularyListView().tag(Tab.vocabulary)
                ExamplesSearchView().tag(Tab.examples)
                ExampleSentenceSearchView().tag(Tab.exampleSentence)
                ExerciseSearchView().tag(Tab.exercise)
                ExerciseAttemptListView().tag(Tab.exerciseAttempt)
                ExerciseQueueListView().tag(Tab.exerciseQueue)
                UserVocabularyStateListView().tag(Tab.userVocabularyState)
                WordListView().tag(Tab.word)
                CambridgeWebView().tag(Tab.cambridge)
                FormListView().tag(Tab.form)
                PhraseListView().tag(Tab.phrase)
                PronounciationListView().tag(Tab.pronunciation)
                TTSView().tag(Tab.tts)
                SenseListView().tag(Tab.sense)
            }
#if !os(macOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
#endif
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            Button("로그아웃") { app.logout() }
        }
        .task {
            do {
                _ = try await PhraseDataSource.shared.loadPhases()
            } catch {
                print("Failed to load phrases: \(error)")
            }
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
