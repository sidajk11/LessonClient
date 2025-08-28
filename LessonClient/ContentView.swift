//
//  ContentView.swift
//  LessonClient
//
//  Created by 정영민 on 8/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    var body: some View {
        RootView()
            .environmentObject(appState)
            .task { await appState.bootstrap() }
            .frame(minWidth: 900, minHeight: 620)
    }
}
#Preview { ContentView() }
