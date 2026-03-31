
import SwiftUI
import Combine

// MARK: - Practice List ViewModel
@MainActor
final class ExerciseListViewModel: ObservableObject {
    let example: Example
    let exampleSentence: ExampleSentence?
    let usePrefetchedExercisesOnly: Bool
    @Published var word: Vocabulary?
    @Published var practices: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init(example: Example, exampleSentence: ExampleSentence? = nil, usePrefetchedExercisesOnly: Bool = false) {
        self.example = example
        self.exampleSentence = exampleSentence ?? example.firstExampleSentence
        self.usePrefetchedExercisesOnly = usePrefetchedExercisesOnly
    }

    // example의 모든 sentence exercise를 합쳐서 보여줄 기본 목록입니다.
    private var prefetchedPractices: [Exercise] {
        let merged = example.orderedExampleSentences.flatMap(\.exercises)
        var seen: Set<Int> = []
        return merged.filter { seen.insert($0.id).inserted }
            .sorted { $0.id > $1.id }
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if let vocabularyId = example.vocabularyId {
                word = try await VocabularyDataSource.shared.vocabulary(id: vocabularyId)
            }

            if usePrefetchedExercisesOnly {
                practices = prefetchedPractices
            } else {
                let fetchedPractices = try await ExerciseDataSource.shared.list(exampleId: example.id)
                // 서버 응답이 비어 있어도 sentence에 달린 prefetched exercise는 유지합니다.
                practices = fetchedPractices.isEmpty ? prefetchedPractices : fetchedPractices
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // exercise가 연결된 sentence 문장을 표시합니다.
    func sentenceText(for exercise: Exercise) -> String {
        let sentenceIds = Set(exercise.targetSentences.map(\.exampleSentenceId))
        let texts = example.orderedExampleSentences
            .filter { sentenceIds.contains($0.id) }
            .map(\.text)
            .filter { !$0.trimmed.isEmpty }

        if texts.isEmpty {
            return exampleSentence?.text ?? ""
        }
        return texts.joined(separator: " / ")
    }
    
    func delete() async {
        
    }
}
