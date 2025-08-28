// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isRegister = false

    var body: some View {
        VStack(spacing: 12) {
            Text(isRegister ? "회원가입" : "로그인").font(.title2).bold()

            TextField("이메일", text: $email).textFieldStyle(.roundedBorder)
            SecureField("비밀번호", text: $password).textFieldStyle(.roundedBorder)

            if let e = error { Text(e).foregroundColor(.red) }

            HStack {
                Button(isRegister ? "가입하기" : "로그인") {
                    Task {
                        do {
                            if isRegister {
                                _ = try await APIClient.shared.register(email: email, password: password)
                            }
                            try await APIClient.shared.login(email: email, password: password)
                            app.user = try await APIClient.shared.me()
                        } catch {
                            self.self.error = (error as NSError).localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(isRegister ? "로그인으로" : "회원가입") {
                    isRegister.toggle()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(minWidth: 380)
    }
}
