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

                NavigationLink {
                    BatchReGenWordView()
                } label: {
                    Text("Word 다시 생성")
                }

                NavigationLink {
                    BatchReGenFormsView()
                } label: {
                    Text("Form 다시 생성")
                }
            }
            .navigationTitle("Batches")
        }
    }
}
