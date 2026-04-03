import SwiftUI

struct BatchesView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    LemmaTestView()
                } label: {
                    Text("LemmaTest")
                }

                NavigationLink {
                    SenseGenTestView()
                } label: {
                    Text("SenseGenTest")
                }

                NavigationLink {
                    BatchAddExamplesView()
                } label: {
                    Text("예문추가")
                }

                NavigationLink {
                    BatchReGenVocabulariesView()
                } label: {
                    Text("예문없는 단어 재생성")
                }
            }
            .navigationTitle("Batches")
        }
    }
}
