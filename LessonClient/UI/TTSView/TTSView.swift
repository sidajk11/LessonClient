//
//  TTSView.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import SwiftUI
import AppKit

struct TTSView: View {
    @StateObject private var tts = GoogleTTSService(apiKey: "")
    @StateObject private var audioPlayer = AudioPlayer()

    @State private var text: String = "apple"
    @State private var status: String = ""
    @State private var accessToken: String = ""

    // 마지막으로 생성된 오디오(임시 파일)
    @State private var lastAudioURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter text", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button("Synthesize & Play") {
                    Task {
                        do {
                            status = "Synthesizing..."
                            let url = try await tts.synthesizeToTempFile(
                                text: text,
                                accessToken: accessToken,
                                voice: .init(languageCode: "en-US", name: "en-US-Neural2-H"),
                                audio: .init(encoding: .mp3)
                            )
                            lastAudioURL = url
                            try audioPlayer.play(url: url)
                            status = "Playing ✅"
                        } catch {
                            status = "Error: \(error)"
                        }
                    }
                }

                Button("Stop") {
                    audioPlayer.stop()
                    status = "Stopped"
                }

                Button("Save MP3") {
                    guard let src = lastAudioURL else { return }
                    do {
                        let suggestedName = sanitizeFilename(text.isEmpty ? "tts" : text) + ".mp3"
                        try saveFileWithPanel(sourceURL: src, suggestedFilename: suggestedName)
                        status = "Saved ✅"
                    } catch {
                        status = "Save failed: \(error)"
                    }
                }
                .disabled(lastAudioURL == nil)
            }

            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 560)
        .task {
            do {
                accessToken = try fetchAccessTokenFromGcloud()
            } catch {
                status = "Error: \(error)"
            }
        }
    }
    
    func fetchAccessTokenFromGcloud() throws -> String {
        return ""
        let process = Process()
        let gcloudPath = "/opt/homebrew/bin/gcloud"
        process.executableURL = URL(fileURLWithPath: gcloudPath)
        process.arguments = ["gcloud", "auth", "application-default", "print-access-token"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - macOS Save Panel helper

private func saveFileWithPanel(sourceURL: URL, suggestedFilename: String) throws {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.isExtensionHidden = false
    panel.nameFieldStringValue = suggestedFilename
    panel.allowedContentTypes = [.mp3]  // requires import UniformTypeIdentifiers
    panel.title = "Save MP3"

    let response = panel.runModal()
    guard response == .OK, let destURL = panel.url else { return }

    // 덮어쓰기 처리: 기존 파일 있으면 삭제 후 복사
    if FileManager.default.fileExists(atPath: destURL.path) {
        try FileManager.default.removeItem(at: destURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destURL)
}

// MARK: - filename sanitize

private func sanitizeFilename(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "tts" }
    let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    return trimmed
        .components(separatedBy: forbidden)
        .joined(separator: "_")
        .replacingOccurrences(of: "\n", with: "_")
        .replacingOccurrences(of: "\r", with: "_")
}
