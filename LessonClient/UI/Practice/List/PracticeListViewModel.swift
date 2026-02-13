
import SwiftUI
import Combine

// MARK: - Practice List ViewModel
@MainActor
final class PracticeListViewModel: ObservableObject {
    let example: Example
    @Published var word: Vocabulary?
    @Published var practices: [Exercise] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init(example: Example) {
        self.example = example
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            // Assumes your data source exposes a list method by example
            let result = try await PracticeDataSource.shared.list(exampleId: example.id)
            if let vocabularyId = example.vocabularyId {
                word = try await VocabularyDataSource.shared.word(id: vocabularyId)
            }
            
            practices = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func delete() async {
        
    }
}
