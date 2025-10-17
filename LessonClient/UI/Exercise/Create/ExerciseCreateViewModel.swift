// MARK: - Exercise Create ViewModel

import SwiftUI
import Combine

@MainActor
final class ExerciseCreateViewModel: ObservableObject {
    // Inputs
    let example: Example
    
    @Published var type: ExerciseType = .select // change as needed
    @Published var words: [String] = []
    @Published var correctionOptionId: Int = 0
    @Published var options: [ExerciseOptionUpdate] = []      // 보기
    @Published var content: [LocalizedText] = []

    // UI State
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var createdExercise: Exercise?

    var canSubmit: Bool {
        !isSubmitting
    }
    
    private var cancellables = Set<AnyCancellable>()

    init(example: Example) {
        self.example = example
        bind()
    }

    func submit() async {
        errorMessage = nil
        createdExercise = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let exerciseCrate = ExerciseUpdate(
                exampleId: example.id,
                info: nil,
                type: type.rawValue,
                words: words.joined(separator: ","),
                options: options
            )
            
            let exercise = try await ExerciseDataSource.shared.create(exercise: exerciseCrate)
            createdExercise = exercise
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
/*
 우리 엄마랑 우리 아빠.
 _ _ _ _ _
 My, mom, and, my, dad
 */
extension ExerciseCreateViewModel {
    private func bind() {
        $type
            .removeDuplicates()
            .sink { [weak self] newType in
                guard let self else { return }
                if newType == .combine {
                    let contentText = content(from: example.text)
                    words = words(from: example.text)
                    let contentTranslation = LocalizedText(langCode: LangCode.enUS.rawValue, text: contentText)
                    content = [contentTranslation]
                }
            }
            .store(in: &cancellables)
    }
    
    private func tokens(from sentence: String) -> [String] {
        // 공백 기준 분리 후 양쪽 구두점 제거
        sentence
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
            .map {
                if $0 == "a.m" {
                    return "a.m."
                } else if $0 == "p.m" {
                    return "p.m."
                } else if !$0.isName {
                    return $0.lowercased()
                } else {
                    return $0
                }
            }
    }
    
    private func content(from sentence: String) -> String {
        // 단어 수만큼 "_" 생성, 마지막 문장부호는 그대로 붙여줌
        let ws = tokens(from: sentence)
        guard !ws.isEmpty else { return "" }
        var q = Array(repeating: "_", count: ws.count).joined(separator: " ")
        if let last = sentence.last, CharacterSet.punctuationCharacters.contains(last.unicodeScalars.first!) {
            q += String(last)
        }
        return q
    }

    private func words(from sentence: String) -> [String] {
        // 문장에 포함된 단어들 (중복 제거, 순서 유지)
        var seen = Set<String>()
        return tokens(from: sentence).filter { word in
            if seen.contains(word.lowercased()) { return false }
            seen.insert(word.lowercased())
            return true
        }
    }
}


