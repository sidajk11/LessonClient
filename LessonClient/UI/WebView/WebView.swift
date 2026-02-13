//
//  WebView.swift
//  LessonClient
//
//  Created by ym on 2/13/26.
//

import SwiftUI
import WebKit

struct CambridgeWebView: View {
    @State private var word: String = ""
    @State private var url: URL? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Enter English word", text: $word)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.go)
                    .onSubmit(load)
                Button("Go") { load() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            if let url {
                WKWebViewContainer(url: url)
            } else {
                ContentUnavailableView("Enter a word", systemImage: "magnifyingglass", description: Text("Type a word and tap Go."))
            }
        }
        .navigationTitle("Cambridge")
    }

    private func load() {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { url = nil; return }
        // Build: https://dictionary.cambridge.org/dictionary/english-korean/{word}
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        url = URL(string: "https://dictionary.cambridge.org/dictionary/english-korean/\(encoded)")
    }
}

#Preview {
    NavigationStack { CambridgeWebView() }
}
