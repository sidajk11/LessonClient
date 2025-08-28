// AppState.swift
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var user: User? = nil
    @Published var loading = false
    @Published var error: String?

    func bootstrap() async {
        guard APIClient.shared.accessToken != nil else { return }
        do {
            loading = true
            user = try await APIClient.shared.me()
        } catch {
            APIClient.shared.accessToken = nil
        }
        loading = false
    }

    func logout() {
        APIClient.shared.accessToken = nil
        user = nil
    }
}
