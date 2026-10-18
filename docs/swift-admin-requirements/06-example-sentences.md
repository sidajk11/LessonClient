# 06. 예문 문장(ExampleSentence)

## FR-SEN-01. 문장 검색

검색어·Level·Unit 입력과 “문장 2개 이상” 필터를 제공한다. 숫자 입력은 숫자만 유지한다. 일반 검색은 `GET /admin/example-sentences/search?q=<trim>&level&unit&limit=400&offset=0`. API가 문장·번역을 검색하며 부모 Vocabulary가 null이라는 이유로 클라이언트에서 제외하지 않는다.

부모 example_id를 모아 중복 없이 GET `/admin/examples/{id}`하여 Unit·문제 등의 문맥을 붙인다. 부모에 같은 sentence ID가 있으면 최신 부모 내 문장을 우선한다. 정렬은 부모 Unit(null 마지막) → Example ID → 문장 order다. 문장별로 text·번역·Unit(U-)·토큰 Sense code/CEFR·연습문제를 표시한다.

## FR-SEN-02. 다중 문장 검색

체크 시 `/admin/example-sentences/multi-sentence?level&unit&limit=400&offset=0`를 사용한다. q는 서버에 보내지 않고 반환 문장 text 또는 번역 text가 q를 대소문자 무시 포함하는지 추가 필터한다. 일반 q 검색 뒤 부모별 문장 수를 임의 계산하는 방식으로 대체하지 않는다. 현재는 첫 400건 검색이며 자동 페이지 추가는 없다.

## FR-SEN-03. 문장 삭제

문장 행 삭제 → 확인 → `DELETE /admin/example-sentences/{sentenceId}`. 성공 시 그 sentence ID 행만 제거한다. 부모 Example·형제 문장을 클라이언트가 DELETE하지 않는다. 삭제 중 ID별 중복 방지, 실패 시 오류 및 행 유지, 취소 시 요청 없음. 종속 토큰/문제 삭제 범위는 서버 계약이다.

## FR-SEN-04. 문장별 문제 삭제·자동 생성

문제 삭제는 부모 Example의 문제를 다시 조회하고 target_sentences에 현재 sentence ID가 포함된 문제만 순서대로 DELETE한다. 형제 문장 전용 문제는 보존한다. 이후 해당 행을 부모 재조회로 갱신한다. 하나의 문제가 여러 문장을 대상으로 하면 문제 자체를 지우는 것이므로 다른 대상에도 영향이 있을 수 있다.

자동 생성은 부모 vocabulary_id가 있으면 Vocabulary를 조회하여 `autoGenerateMissingExercises`에 전달한다. 없으면 nil로 전달하여 가능한 combine만 생성한다. 이미 있는 유형은 중복 생성하지 않는다. 생성 중 sentence ID별 진행 상태와 오류를 표시한다.

## FR-SEN-05. 문장 상세 편집

선택 sentence ID를 유지하고 부모 Example을 읽어 해당 문장을 찾는다. 영어 문장과 다국어 번역을 편집한다. trim 후 빈 문장은 거절한다. `PUT /admin/example-sentences/{id} {text,translations}` 후 부모를 다시 GET하고 같은 ID를 재선택한다. 선택 대상이 해석되지 않아 편집 불가능하면 보기 전용 안내를 표시한다. 형제 문장이나 부모의 대표 텍스트로 저장 대상을 바꾸지 않는다. 문제 목록·토큰 상세로 이동할 수 있다. 토큰 도구는 07번 문서 참조.

## FR-SEN-06. 블록 문장 추가 하위 화면

Vocabulary ID를 받은 생성 화면은 빈 줄로 여러 블록을 받는다. 각 블록 첫 줄 영어 문장, 이후 언어별 번역. 아포스트로피 정규화 후 블록마다 연결 Example을 먼저 만들고 문장을 생성한다. 전부 생성 후 Vocabulary를 읽고 각 문장의 누락 문제를 자동 생성한다. 문제 생성 실패는 이미 생성한 문장을 삭제하지 않는다. 이 흐름은 Vocabulary 상세의 간단한 한 문장 추가와 별개다.

## AC-SEN

1. Vocabulary 미연결 문장도 q 검색 결과로 표시할 수 있다.
2. 같은 부모의 S1·S2 중 S2를 편집하면 S1은 바뀌지 않는다.
3. S2 삭제 시 DELETE 경로는 sentence ID이며 example ID가 아니다.
4. 일반 검색은 q를 서버로, 다중 문장 모드는 q를 로컬 필터로 사용한다.
5. 부모 Vocabulary 없는 문장에서 자동 생성은 연결 없는 이유만으로 combine을 막지 않는다.

근거: `LessonClient/UI/ExampleSentence/` 전체, `LessonClient/DataSource/ExampleSentenceDataSource.swift`.
