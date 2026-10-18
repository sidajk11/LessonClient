# 16. 문장 유닛 검사

진입: Batches → 문장유닛검사. 목적은 입력 문장에 포함된 학습 단어 중 가장 높은 Lesson Unit을 찾는 것이다. CEFR 최댓값이나 단어 길이를 계산하는 기능이 아니다.

## FR-UNT-01. 입력·검사 상태

여러 줄 영어 문장 입력 및 검사 버튼. trim 후 빈 문자열이거나 검사 중이면 실행하지 않는다. 실행할 때 이전 결과·오류·빈 결과 메시지를 초기화한다. 처리 중 로딩을 표시한다. 저장/삭제 없이 GET과 로컬 분석만 한다.

## FR-UNT-02. 분석 알고리즘

1. 07번과 동일한 tokenizer 및 Phrase 병합으로 token draft를 만든다. DB 토큰 레코드는 만들지 않는다.
2. 문장부호를 제외한 표면형을 중복 제거하고 학습 Vocabulary를 해석한다. q 후보 중 정규화 정확 일치를 찾고, 필요하면 Form 조회를 통한 Vocabulary fallback을 사용한다.
3. 해석된 Vocabulary의 lesson_id가 있으면 Lesson을 조회해 Unit을 구한다. 같은 Lesson은 한 검사 내 캐시한다. 미연결·조회 후보 없음은 최고값 후보에서 제외한다.
4. 순회하면서 현재보다 큰 Unit만 결과를 교체한다. 같은 최고 Unit이면 먼저 선택된 후보를 유지한다.
5. 결과는 최고 Unit과 그에 대응한 문장 단어/학습 단어 정보를 표시한다. 모든 단어를 조회하지 못했다는 이유로 Unit=0을 만들어 표시하지 않는다.

정확한 Vocabulary 후보/동일 단어/형태 fallback 우선순위는 `reference/SentenceVocabularyAnalysisUseCase.swift`에 포함한다. 단순 표제어 문자열만 조회하거나 Word 자체의 순번을 Unit으로 쓰지 않는다.

## FR-UNT-03. 결과·오류

Unit 연결 단어가 하나도 없으면 “문장에서 unit이 연결된 학습 단어를 찾지 못했습니다.”. 호출 실패는 “문장 unit 검사에 실패했습니다: …” 오류. “대상 없음”과 네트워크 오류를 같은 메시지로 합치지 않는다.

## AC-UNT

1. mock에서 plants=U8, animals=U12이면 `beautiful plants and animals` 결과는 U12와 animals다.
2. 같은 단어 반복은 결과를 바꾸지 않으며 Lesson 캐시를 재사용한다.
3. 모든 Vocabulary 미연결이면 U0 대신 대상 없음 메시지다.
4. 등록된 여러 단어 Phrase는 우선 병합되어 Phrase에 대응하는 Vocabulary도 검사된다.
5. 검사 전체에서 POST·PUT·DELETE가 발생하지 않는다.

근거: `LessonClient/UI/SentenceUnitCheck/`, `LessonClient/Domain/UseCase/ExampleSentence/SentenceVocabularyAnalysisUseCase.swift`.
