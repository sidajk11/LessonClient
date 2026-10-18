// swift-tools-version: 5.9
import PackageDescription

// Test the app's actual model/data-source sources without launching the GUI.
let package = Package(
    name: "LessonClientParity",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "LessonClientCore", path: "LessonClient", exclude: [
            "AI", "App", "Assets.xcassets", "Info.plist", "LessonClient.entitlements",
            "Domain/UseCase", "Domain/Example", "Domain/Parsers/SentenseParser.swift",
            "UI/Auth", "UI/Batches", "UI/Example", "UI/ExampleSentence", "UI/Exercise", "UI/ExerciseAttempt", "UI/ExerciseQueue", "UI/Form", "UI/Lesson", "UI/Phrase", "UI/Pronounciation", "UI/Sense", "UI/SentenceToken", "UI/SentenceUnitCheck", "UI/TTSView", "UI/UnitLevel", "UI/UserLessonTargetState", "UI/Vocabulary", "UI/WebView", "UI/Word"
        ], sources: ["API", "Models", "DataSource", "Utils/Extensions", "Domain/Parsers/SenseBulkParser.swift", "UI/Data/Models+Extension.swift"]),
        .testTarget(name: "LessonClientParityTests", dependencies: ["LessonClientCore"], path: "ParityTests")
    ],
    swiftLanguageVersions: [.v5]
)
