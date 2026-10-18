# 알고리즘·프롬프트·계약 참고 원문

추가 실행 흐름 원문:
- [BatchAddExamplesViewModel.swift](BatchAddExamplesViewModel.swift) — `LessonClient/UI/Batches/BatchAddExamplesViewModel.swift`
- [BatchAddLessonsViewModel.swift](BatchAddLessonsViewModel.swift) — `LessonClient/UI/Batches/BatchAddLessonsViewModel.swift`
- [BatchDeleteLessonsViewModel.swift](BatchDeleteLessonsViewModel.swift) — `LessonClient/UI/Batches/BatchDeleteLessonsViewModel.swift`
- [BatchReGenFormsViewModel.swift](BatchReGenFormsViewModel.swift) — `LessonClient/UI/Batches/BatchReGenFormsViewModel.swift`
- [BatchReGenVocabulariesViewModel.swift](BatchReGenVocabulariesViewModel.swift) — `LessonClient/UI/Batches/BatchReGenVocabulariesViewModel.swift`
- [BatchReGenWordViewModel.swift](BatchReGenWordViewModel.swift) — `LessonClient/UI/Batches/BatchReGenWordViewModel.swift`
- [LemmaTestViewModel.swift](LemmaTestViewModel.swift) — `LessonClient/UI/Batches/LemmaTestViewModel.swift`
- [SenseGenTestViewModel.swift](SenseGenTestViewModel.swift) — `LessonClient/UI/Batches/SenseGenTestViewModel.swift`
- [ExerciseCreateViewModel.swift](ExerciseCreateViewModel.swift) — `LessonClient/UI/Exercise/Create/ExerciseCreateViewModel.swift`
- [ExerciseDetailViewModel.swift](ExerciseDetailViewModel.swift) — `LessonClient/UI/Exercise/Detail/ExerciseDetailViewModel.swift`
- [ExerciseListViewModel.swift](ExerciseListViewModel.swift) — `LessonClient/UI/Exercise/List/ExerciseListViewModel.swift`
- [ExerciseSearchViewModel.swift](ExerciseSearchViewModel.swift) — `LessonClient/UI/Exercise/Search/ExerciseSearchViewModel.swift`
- [FormCreateViewModel.swift](FormCreateViewModel.swift) — `LessonClient/UI/Form/Create/FormCreateViewModel.swift`
- [LessonBulkCreateViewModel.swift](LessonBulkCreateViewModel.swift) — `LessonClient/UI/Lesson/BulkCreate/LessonBulkCreateViewModel.swift`
- [VocabularyDetailViewModel.swift](VocabularyDetailViewModel.swift) — `LessonClient/UI/Vocabulary/Detail/VocabularyDetailViewModel.swift`
- [JSONCoder+LessonClient.swift](JSONCoder+LessonClient.swift) — `LessonClient/Utils/Extensions/JSONCoder+LessonClient.swift`

2026-10-17 현재 작업 파일의 읽기 전용 사본이다. 앱에서 컴파일하거나 실행할 파일이 아니며 Swift 플랫폼 의존 기능은 재구현 플랫폼의 동등 동작으로 옮긴다. 기능별 Markdown이 업무 요구사항이고, 이 폴더는 정확한 프롬프트·파싱·후보 선택·JSON 키를 보존하는 기술 부록이다. 현재 결함도 원문에 남아 있으므로 19-current-limitations.md를 우선 확인한다. 자격 증명 클라이언트는 포함하지 않았다. 서버 구현은 포함하지 않는다.

| 사본 | 원본 경로 |
|---|---|
| [FormPrompts.swift](FormPrompts.swift) | `LessonClient/AI/Prompts/FormPrompts.swift` |
| [IndependentWordPrompts.swift](IndependentWordPrompts.swift) | `LessonClient/AI/Prompts/IndependentWordPrompts.swift` |
| [PhrasePrompts.swift](PhrasePrompts.swift) | `LessonClient/AI/Prompts/PhrasePrompts.swift` |
| [SensePrompts.swift](SensePrompts.swift) | `LessonClient/AI/Prompts/SensePrompts.swift` |
| [SentenceLemmas.swift](SentenceLemmas.swift) | `LessonClient/AI/Prompts/SentenceLemmas.swift` |
| [SentencePrompts.swift](SentencePrompts.swift) | `LessonClient/AI/Prompts/SentencePrompts.swift` |
| [SentenceTokenPrompts.swift](SentenceTokenPrompts.swift) | `LessonClient/AI/Prompts/SentenceTokenPrompts.swift` |
| [ExampleDataSource.swift](ExampleDataSource.swift) | `LessonClient/DataSource/ExampleDataSource.swift` |
| [ExampleSentenceDataSource.swift](ExampleSentenceDataSource.swift) | `LessonClient/DataSource/ExampleSentenceDataSource.swift` |
| [ExerciseAttemptDataSource.swift](ExerciseAttemptDataSource.swift) | `LessonClient/DataSource/ExerciseAttemptDataSource.swift` |
| [ExerciseDataSource.swift](ExerciseDataSource.swift) | `LessonClient/DataSource/ExerciseDataSource.swift` |
| [ExerciseQueueDataSource.swift](ExerciseQueueDataSource.swift) | `LessonClient/DataSource/ExerciseQueueDataSource.swift` |
| [LessonDataSource.swift](LessonDataSource.swift) | `LessonClient/DataSource/LessonDataSource.swift` |
| [PhraseDataSource.swift](PhraseDataSource.swift) | `LessonClient/DataSource/PhraseDataSource.swift` |
| [PronunciationDataSource.swift](PronunciationDataSource.swift) | `LessonClient/DataSource/PronunciationDataSource.swift` |
| [SentenceTokenDataSource.swift](SentenceTokenDataSource.swift) | `LessonClient/DataSource/SentenceTokenDataSource.swift` |
| [UnitLevelDataSource.swift](UnitLevelDataSource.swift) | `LessonClient/DataSource/UnitLevelDataSource.swift` |
| [UserDataSource.swift](UserDataSource.swift) | `LessonClient/DataSource/UserDataSource.swift` |
| [UserVocabularyStateDataSource.swift](UserVocabularyStateDataSource.swift) | `LessonClient/DataSource/UserVocabularyStateDataSource.swift` |
| [VocabularyDataSource.swift](VocabularyDataSource.swift) | `LessonClient/DataSource/VocabularyDataSource.swift` |
| [WordDataSource.swift](WordDataSource.swift) | `LessonClient/DataSource/WordDataSource.swift` |
| [WordFormDataSource.swift](WordFormDataSource.swift) | `LessonClient/DataSource/WordFormDataSource.swift` |
| [SentenceTokenPhraseMerger.swift](SentenceTokenPhraseMerger.swift) | `LessonClient/Domain/Example/SentenceTokenPhraseMerger.swift` |
| [SenseBulkParser.swift](SenseBulkParser.swift) | `LessonClient/Domain/Parsers/SenseBulkParser.swift` |
| [SentenseParser.swift](SentenseParser.swift) | `LessonClient/Domain/Parsers/SentenseParser.swift` |
| [BuildTokenLLMTextUseCase.swift](BuildTokenLLMTextUseCase.swift) | `LessonClient/Domain/UseCase/ExampleSentence/BuildTokenLLMTextUseCase.swift` |
| [GenerateTokensUseCase.swift](GenerateTokensUseCase.swift) | `LessonClient/Domain/UseCase/ExampleSentence/GenerateTokensUseCase.swift` |
| [SentenceVocabularyAnalysisUseCase.swift](SentenceVocabularyAnalysisUseCase.swift) | `LessonClient/Domain/UseCase/ExampleSentence/SentenceVocabularyAnalysisUseCase.swift` |
| [TokenRangesUseCase.swift](TokenRangesUseCase.swift) | `LessonClient/Domain/UseCase/ExampleSentence/TokenRangesUseCase.swift` |
| [ExerciseUseCases.swift](ExerciseUseCases.swift) | `LessonClient/Domain/UseCase/Exercise/ExerciseUseCases.swift` |
| [GenerateExerciseUseCase.swift](GenerateExerciseUseCase.swift) | `LessonClient/Domain/UseCase/Exercise/GenerateExerciseUseCase.swift` |
| [RegenerateFormsForVocabulariesWithoutExamplesUseCase.swift](RegenerateFormsForVocabulariesWithoutExamplesUseCase.swift) | `LessonClient/Domain/UseCase/Vocabulary/RegenerateFormsForVocabulariesWithoutExamplesUseCase.swift` |
| [RegenerateVocabulariesWithoutExamplesUseCase.swift](RegenerateVocabulariesWithoutExamplesUseCase.swift) | `LessonClient/Domain/UseCase/Vocabulary/RegenerateVocabulariesWithoutExamplesUseCase.swift` |
| [VocabularyLinkAuditUseCase.swift](VocabularyLinkAuditUseCase.swift) | `LessonClient/Domain/UseCase/Vocabulary/VocabularyLinkAuditUseCase.swift` |
| [GenerateWordUseCase.swift](GenerateWordUseCase.swift) | `LessonClient/Domain/UseCase/Word/GenerateWordUseCase.swift` |
| [RegenerateWordsBeforeDateUseCase.swift](RegenerateWordsBeforeDateUseCase.swift) | `LessonClient/Domain/UseCase/Word/RegenerateWordsBeforeDateUseCase.swift` |
| [AutoGenerateWordSensesUseCase.swift](AutoGenerateWordSensesUseCase.swift) | `LessonClient/Domain/UseCase/WordSense/AutoGenerateWordSensesUseCase.swift` |
| [WordUseCase.swift](WordUseCase.swift) | `LessonClient/Domain/UseCase/WordUseCase.swift` |
| [Defines.swift](Defines.swift) | `LessonClient/Models/Defines.swift` |
| [Example.swift](Example.swift) | `LessonClient/Models/Example.swift` |
| [ExampleSentence.swift](ExampleSentence.swift) | `LessonClient/Models/ExampleSentence.swift` |
| [ExerciseAttemptModel.swift](ExerciseAttemptModel.swift) | `LessonClient/Models/ExerciseAttemptModel.swift` |
| [ExerciseModel.swift](ExerciseModel.swift) | `LessonClient/Models/ExerciseModel.swift` |
| [ExerciseQueueModel.swift](ExerciseQueueModel.swift) | `LessonClient/Models/ExerciseQueueModel.swift` |
| [LessonTarget.swift](LessonTarget.swift) | `LessonClient/Models/LessonTarget.swift` |
| [Models.swift](Models.swift) | `LessonClient/Models/Models.swift` |
| [Phrase.swift](Phrase.swift) | `LessonClient/Models/Phrase.swift` |
| [PronunciationModel.swift](PronunciationModel.swift) | `LessonClient/Models/PronunciationModel.swift` |
| [SentenceToken.swift](SentenceToken.swift) | `LessonClient/Models/SentenceToken.swift` |
| [UnitLevelModel.swift](UnitLevelModel.swift) | `LessonClient/Models/UnitLevelModel.swift` |
| [UserLessonTargetStateModel.swift](UserLessonTargetStateModel.swift) | `LessonClient/Models/UserLessonTargetStateModel.swift` |
| [VocabularyModel.swift](VocabularyModel.swift) | `LessonClient/Models/VocabularyModel.swift` |
| [Word.swift](Word.swift) | `LessonClient/Models/Word.swift` |
| [WordForm.swift](WordForm.swift) | `LessonClient/Models/WordForm.swift` |
| [Models+Extension.swift](Models+Extension.swift) | `LessonClient/UI/Data/Models+Extension.swift` |
| [ExampleTokenVocabularyStatusLoader.swift](ExampleTokenVocabularyStatusLoader.swift) | `LessonClient/UI/Example/Search/ExampleTokenVocabularyStatusLoader.swift` |
| [ExamplesSearchViewModel.swift](ExamplesSearchViewModel.swift) | `LessonClient/UI/Example/Search/ExamplesSearchViewModel.swift` |
| [ExampleSentenceDetailViewModel.swift](ExampleSentenceDetailViewModel.swift) | `LessonClient/UI/ExampleSentence/Detail/ExampleSentenceDetailViewModel.swift` |
| [FormBlocksParser.swift](FormBlocksParser.swift) | `LessonClient/UI/Form/Create/FormBlocksParser.swift` |
| [VocabularyListViewModel.swift](VocabularyListViewModel.swift) | `LessonClient/UI/Vocabulary/List/VocabularyListViewModel.swift` |
| [WordDetailViewModel.swift](WordDetailViewModel.swift) | `LessonClient/UI/Word/Detail/WordDetailViewModel.swift` |
| [NaturalLanguage+Extension.swift](NaturalLanguage+Extension.swift) | `LessonClient/Utils/Extensions/NaturalLanguage+Extension.swift` |
| [String+Extension.swift](String+Extension.swift) | `LessonClient/Utils/Extensions/String+Extension.swift` |

