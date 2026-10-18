# 10. 사전 단어(Word)

## FR-WRD-01. 검색·목록

실제 입력은 q와 Word ID다. 일반 검색 `GET /admin/words?q&limit=50&offset=0`. ViewModel/DataSource는 kind도 지원하지만 현재 목록 UI에 kind/POS 필터 입력은 없다. Word ID가 있으면 단건 GET이 q보다 우선한다. q 검색의 서버 범위를 Vocabulary의 Level·Unit 검색과 혼동하지 않는다. 마지막 행에서 다음 페이지 추가. 행은 lemma·normalized/kind·대표 POS·Sense 수·IPA와 번역 완성 상태 등을 표시한다. 번역 완성 상태는 현재 첫 Sense의 언어 수 기준이며 모든 Sense 번역의 품질 검증이 아니다.

## FR-WRD-02. 삭제

확인 후 로드된 Word의 Sense를 각각 DELETE하고 Word를 DELETE한다. Form·Pronunciation 등 모든 종속 개체를 항상 자동 삭제한다고 가정하지 않는다. 중간 오류는 일부 Sense만 삭제된 상태일 수 있다. 실패는 보고하고 목록을 성공처럼 제거하지 않는다. 배치 Word 재생성의 의존성 삭제 흐름과 다르다.

## FR-WRD-03. 상세·POS 편집

Word와 Sense 목록을 읽어 Sense별 sense_code·품사·CEFR·뜻·번역·예문 등을 표시한다. 각 Sense의 POS를 편집하고 변경된 항목만 PUT한다. trim 후 빈 POS는 nil 의도이며 저장 중 중복 금지. Word의 표제어를 Vocabulary 기본 텍스트 저장과 같은 기능으로 취급하지 않는다.

## FR-WRD-04. Sense 하나 추가

블록 입력 형식은 Sense 생성 규칙(14번)과 동일하지만 정확히 1개 블록만 허용하고 headword가 현재 Word lemma와 대소문자 무시 일치해야 한다. 새 sense_code는 현재 Sense 수+1을 사용한다. Sense 생성 → Example → ExampleSentence → 대표 예문 연결 순서로 처리한다. 현재 이 경로에는 Word ID를 vocabulary_id로 보내는 결함이 있으므로 19번 문서의 의도/현재 차이를 확인해야 한다.

## FR-WRD-05. Sense 번역 블록 추가·갱신

여러 Sense용 블록을 `---`로 나눠 순서대로 현재 Sense에 대응한다. 선택적 Word 헤더, `sense_en` 또는 언어별 뜻·설명 필드를 해석한다. 각 언어를 `PUT /admin/words/senses/{senseId}/translations {lang,text,explain}`로 upsert한다. 블록과 Sense 개수 중 작은 수까지만 처리하는 현재 한계가 있다. sense_code 키로 자동 대응한다고 바꾸지 않는다. 지원 키와 fallback은 reference의 WordDetailViewModel을 기준으로 한다.

## FR-WRD-06. Sense 예문 연결

Sense별 “예문 연결”에서 `/admin/examples/search?q&limit=50`로 부모 예문을 검색하고 이미 붙은 ID는 제외한다. 연결은 `POST /admin/words/senses/{senseId}/examples {example_id,is_prime:false}`. 409 중복 연결 오류를 표시한다. Vocabulary 예문 연결과 달리 Sense-Example 연결이며 부모 vocabulary_id를 변경하지 않는다. 이 검색은 현재 Vocabulary의 문장 검색 방식과 다르다.

## FR-WRD-07. 전체 Sense 삭제·복사

“전체 Sense 삭제”는 확인 후 Sense들을 순차 삭제하며 개별 실패·부분 성공을 보고한다. Word 자체를 함께 삭제하는 동작이 아니다. 복사는 Word·Sense·번역·예문을 다시 입력 가능한 포맷의 텍스트로 만든다. 복사는 서버 변경 없이 클립보드만 갱신한다. Form·발음 등 하위 화면 연결이 있는 경우 현재 Word ID 문맥을 전달한다.

## AC-WRD

1. Word ID 입력 시 q 검색 API가 아니라 해당 ID 단건을 읽는다.
2. Sense 예문 연결 시 vocabulary_id PUT가 발생하지 않는다.
3. 다른 lemma의 Sense 블록과 2개 블록은 단일 Sense 추가에서 거절한다.
4. 변경 없는 POS는 PUT하지 않는다.
5. Word 전체 삭제와 Sense 전체 삭제는 서로 다른 최종 결과를 가진다.

근거: `LessonClient/UI/Word/`, `LessonClient/DataSource/WordDataSource.swift`.
