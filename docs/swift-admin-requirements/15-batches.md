# 15. Batches 하위 기능

메뉴 순서는 LemmaTest → SenseGenTest → 예문추가 → 예문없는 단어 재생성 → Word 다시 생성 → Form 다시 생성 → 레슨 삭제 → 레슨 추가 → 문장유닛검사. 마지막 기능은 16번 문서에 별도 정의한다. 버튼이 있는 AI 실험과 DB를 쓰는 재생성을 명확히 구분한다.

## FR-BAT-01. LemmaTest

영어 입력 → lemma 프롬프트 AI 호출 → 결과 텍스트 표시. 로딩·빈 입력 제한·호출 실패를 표시한다. 출력으로 Word나 Vocabulary를 자동 생성하지 않는다. 프롬프트는 reference/SentenceLemmas.swift.

## FR-BAT-02. SenseGenTest

입력 단어로 Sense 프롬프트를 호출하고 결과를 텍스트로 표시한다. 저장 기능이 아니라 프롬프트 실험이다. reference/SensePrompts.swift를 사용하며 DB POST·PUT·DELETE를 하지 않는다.

## FR-BAT-03. 예문추가

Topic·CEFR·단어 목록 입력. 단어는 쉼표/줄바꿈으로 나눈다. Topic·수준·단어별 최대 10문장과 고정 등장인물 조건(Mia·Emma, 두 살)을 프롬프트에 반영한다. 응답은 `[word]` 구역별 결과로 표시한다. 이 화면의 이름과 달리 자동 DB 저장이 아니라 생성 결과 확인용이다. 학습 단어 목록의 “예문 만들기” 저장 기능과 다르다.

## FR-BAT-04. 예문 없는 단어 재생성

입력 단어 모드와 전체 후보 모드를 제공한다. 전체는 예문 없는 Vocabulary를 페이지 조회하고, 입력 모드는 해당 Vocabulary를 정확 일치로 찾는다. Vocabulary의 직접 word_id → Sense의 Word → Form의 Word 등으로 연결 Word를 해석한다. 연결이 없으면 text로 생성 후보를 만든다. 동일 Word 작업은 중복 제거한다.

기본 날짜 기준은 2026-04-02 00:00 Asia/Seoul이며 기준보다 이전 생성 Word가 대상이다. 기준 날짜·시각·동등 비교를 임의로 현재 날짜로 바꾸지 않는다. 의존 발음·Form·Sense·Word를 삭제 후 자동 생성한다. 완료 후 Vocabulary 연결 검사·적용으로 링크를 보정한다. 대상 수·처리 수·실패·현재 Word를 표시한다。Word 다시 생성과 달리 이 화면에 별도 중단 버튼은 없다. 삭제 후 재생성 실패는 원본 복구를 보장하지 않는다. 정밀 대상 분기와 순서는 reference의 RegenerateVocabulariesWithoutExamplesUseCase.

## FR-BAT-05. Word 다시 생성

기본 기준 2026-04-02 00:00 Asia/Seoul 이전 Word를 전체 페이지(limit=200)에서 선별한다. created_at 없음·숫자로만 된 Word는 제외한다. 발음 → Form → Sense → Word 삭제 후 자동 Word/Sense 생성. 건별 실패 후 다음 대상 계속, 진행 및 실패 로그 표시. 중단은 현재 진행 요청을 rollback하는 것이 아니라 다음 작업을 멈추는 협력적 중단이다.

입력 단어 생성은 삭제 없이 생성, 입력 단어 재생성은 기존 Word를 찾아 삭제 후 생성하는 별도 동작이다. 입력은 정규화·중복 제거·숫자만 제외. 입력 모드의 실제 날짜 제한 사용 여부는 전체 모드와 같다고 가정하지 않는다(현재 입력 재생성은 cutoff 제한을 적용하지 않는 경로가 있다).

## FR-BAT-06. Form 다시 생성

기본 기준 2026-04-03 18:25 Asia/Seoul. 전체 후보는 실제 Word 전체 페이지 기반이며 클래스명만 보고 예문 없는 Vocabulary로 한정하지 않는다. 입력 Vocabulary 모드에서는 연결 Word를 해석한다. 중복 Word ID 제거·공백 포함 Phrase 제외·날짜 선별 후 기존 Form 삭제 → Form 프롬프트 생성 → 파싱·저장한다. 기준 이후 생성된 Word 수 검사(countWords)와 진행·실패를 제공하며 별도 중단 버튼은 없다. Form 추가 화면의 “없는 Form만 추가”와 다르다.

## FR-BAT-07. 레슨 삭제

시작 Unit·끝 Unit은 양의 정수이며 끝≥시작. 범위 Unit을 하나씩 조회(limit=200)하고 해당 레슨들을 순차 DELETE한다. Unit 범위는 양 끝 포함. 범위 삭제 안내문과 실행 진행·결과를 제공한다. 현재 버튼은 추가 확인 대화상자 없이 실행된다. 실패 시 중단하고 이미 삭제한 레슨은 자동 복원하지 않는다. 서버 cascade를 확정하지 않는다.

## FR-BAT-08. 레슨 추가

Topic 필수, 시작 Unit 기본 nextUnit, 입력은 한 줄 `word^한국어뜻` 형식이다. 단어 두 개씩 연속 Unit에 넣고 Level=1. 기존 Unit 레슨은 재사용한다. 기존 정확 일치 Vocabulary가 미배정이면 연결, 다른 레슨이면 유지한다. 한국어 뜻이 있으면 기존 번역과 병합·갱신한다. 새 Vocabulary에는 Phrase/Form/s1 Sense 메타데이터를 해석하여 연결한다. 진행 레슨·단어·생성/재사용 건수를 표시한다. 첫 예외에서 중단하며 이전 성공은 유지한다. 레슨 메뉴의 쉼표/세미콜론 단어 일괄 생성 입력과 구분한다.

## AC-BAT

1. LemmaTest·SenseGenTest·예문추가는 fixture AI 결과로 화면만 바뀌고 DB 쓰기 0회다.
2. 동일 Word에 대응하는 Vocabulary 두 개가 있어도 재생성은 한 번이다.
3. 날짜가 기준과 같은 Word는 “이전” 대상에 포함하지 않는다.
4. 중단 후 다음 Word 삭제를 시작하지 않는다. 이미 실행된 삭제는 취소됐다고 표시하지 않는다.
5. 시작 5·끝 4는 거절하며 범위 5~6은 U5·U6만 조회한다.

근거: `LessonClient/UI/Batches/` 전체, `LessonClient/Domain/UseCase/Vocabulary/Regenerate*`, `LessonClient/Domain/UseCase/Word/RegenerateWordsBeforeDateUseCase.swift`.
