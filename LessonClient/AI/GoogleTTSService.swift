//
//  GoogleTTSService.swift
//  LessonClient
//
//  Created by ym on 2/23/26.
//

import Foundation
import AVFoundation

/// Google Cloud Text-to-Speech (REST) - Text -> Speech
/// - Uses API Key for simplicity.
/// - For production, prefer calling your own backend (service account OAuth) instead of shipping keys in the app.
final class GoogleTTSService: ObservableObject {

    enum TTSServiceError: Error {
        case invalidURL
        case badStatus(Int, String)
        case missingAudioContent
        case base64DecodeFailed
        case audioFileWriteFailed
    }

    struct Voice {
        var languageCode: String = "en-US"
        /// Example: "en-US-Neural2-A" or leave nil to let Google choose a default voice for the language.
        var name: String? = "en-US-Neural2-A"
    }

    struct AudioConfig {
        enum Encoding: String {
            case mp3 = "MP3"
            case linear16 = "LINEAR16" // WAV-like PCM
            case oggOpus = "OGG_OPUS"
        }

        var encoding: Encoding = .mp3
        /// Optional speaking rate: 0.25 ~ 4.0
        var speakingRate: Double? = nil
        /// Optional pitch: -20.0 ~ 20.0
        var pitch: Double? = nil
    }

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Synthesize speech from plain text and returns a local file URL you can play.
    /// - Note: Writes audio into the app's temporary directory.
    @MainActor
    func synthesizeToTempFile(
        text: String,
        accessToken: String,
        voice: Voice = .init(),
        audio: AudioConfig = .init()
    ) async throws -> URL {

        guard let components = URLComponents(string: "https://texttospeech.googleapis.com/v1/text:synthesize") else {
            throw TTSServiceError.invalidURL
        }
        //components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw TTSServiceError.invalidURL
        }

        // Build request JSON
        var voiceDict: [String: Any] = [
            "languageCode": voice.languageCode
        ]
        if let name = voice.name {
            voiceDict["name"] = name
        }

        var audioConfig: [String: Any] = [
            "audioEncoding": audio.encoding.rawValue
        ]
        if let speakingRate = audio.speakingRate { audioConfig["speakingRate"] = speakingRate }
        if let pitch = audio.pitch { audioConfig["pitch"] = pitch }

        let payload: [String: Any] = [
            "input": ["text": text],
            "voice": voiceDict,
            "audioConfig": audioConfig
        ]

        let body = try JSONSerialization.data(withJSONObject: payload, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.setValue("elserver-470100", forHTTPHeaderField: "x-goog-user-project")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw TTSServiceError.badStatus(http.statusCode, message)
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let audioContentB64 = json?["audioContent"] as? String else {
            throw TTSServiceError.missingAudioContent
        }

        guard let audioData = Data(base64Encoded: audioContentB64) else {
            throw TTSServiceError.base64DecodeFailed
        }

        let fileExt: String
        switch audio.encoding {
        case .mp3: fileExt = "mp3"
        case .linear16: fileExt = "wav"
        case .oggOpus: fileExt = "ogg"
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_\(UUID().uuidString).\(fileExt)")

        do {
            try audioData.write(to: tempURL, options: [.atomic])
        } catch {
            throw TTSServiceError.audioFileWriteFailed
        }

        return tempURL
    }
}

// MARK: - Optional: tiny helper player you can use in SwiftUI

@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?

    func play(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        isPlaying = player?.play() ?? false
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }
}
