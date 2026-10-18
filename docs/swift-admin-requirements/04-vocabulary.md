# 04. 학습 단어(Vocabulary)

## FR-VOC-01. 단어·Level·Unit 검색

세 입력값을 조합하여 검색/Enter로 조회한다. 단어는 trim, Level·Unit은 빈 값이면 전체, 비어 있지 않은 비정수는 오류를 표시하고 요청하지 않는다. q가 있으면 `GET /admin/vocabularies/search?q&level&unit&limit=30`, 없으면 `GET /admin/vocabularies?level&unit&limit=600&offset=0`. 검색의 부분일치·서버 정렬은 서버 응답 기준이며 클라이언트가 정확 일치 검색으로 좁히지 않는다. 현재 화면은 자동 추가 페이지가 아니다.

행: text, Unit이 있으면 U번호, 번역 요약, 예문 없음/개수, 검사 결과·연결 ID·CEFR. 선택 시 Vocabulary 상세로 간다.

## FR-VOC-02. 예문 없는 단어 필터

체크 변경 시 재검색한다. 검색 결과 각각에 `GET /admin/examples/by-vocabulary/{id}?limit=1`을 호출해 실제 예문이 없는 것만 남긴다. 조회 진행 건수·단어를 표시한다. 내장 examples 빈 배열만으로 서버 조회를 대체하지 않는다.

## FR-VOC-03. 연결 검사·검사결과 적용

“검사”는 현재 표시 대상의 phrase/form/sense 연결을 읽기 전용으로 계산한다. 입력 text를 아포스트로피·trim·대소문자·악센트 정규화하여 후보와 정확 비교한다. Phrase는 text 또는 normalized 일치, Form은 form 일치로 선택한다. is_form=false이면 기대 Form은 null이고 원래 text의 Word를 찾는다. is_form=true이고 일치 Form이 있으면 해당 Word lemma로 Sense를 찾는다. Sense는 sense_code 숫자 우선으로 가장 작은 것을 택한다(s2가 s10보다 먼저). CEFR는 표시 정보이며 현재 선택 알고리즘의 제한 조건이 아니다.

현재/기대 p/f/s 중 하나라도 다르면 “센스수정 필요”, 모두 같으면 “정상”. API 실패는 “검사 실패”와 오류를 별도 저장한다. “검사 실패 단어만”은 auditFailureMessage가 있는 조회 실패 항목만 표시하며 단순 연결 불일치 항목까지 포함하는 필터가 아니다. DB 변경은 없다. 필터 때문에 표시가 비었을 때 검사 대상은 원래 items로 되돌아간다.

“검사결과 적용”은 계산된 차이가 있는 항목만 `PUT /admin/vocabularies/{id}`로 전체 보존 필드와 기대 연결값을 보낸다. 없어져야 하는 FK는 명시적 null을 보낸다. 검사만으로 자동 수정하지 않는다. 건별 오류는 기록하고 다음 항목을 계속한다. 진행·성공·실패 수를 표시한다. 정밀 비교 규칙은 `reference/VocabularyLinkAuditUseCase.swift`다.

## FR-VOC-04. AI 예문 만들기

현재 표시 단어를 대상으로 설정 sheet를 연다. CEFR 기본 B1. 각 단어의 lesson_id로 Topic을 조회하고 ko Topic 우선, 없으면 첫 번역 Topic을 사용한다. 레슨 미연결·Topic 없음은 해당 단어 오류다. Topic은 레슨별 캐시한다. Topic·CEFR·단어로 Sentence 프롬프트를 호출하여 응답의 문장을 파싱·중복 제거한다. 각 문장을 현재 Vocabulary에 연결한 Example과 ExampleSentence로 저장한다. 결과 예문 수와 실패를 표시하며 “예문 없는 단어만” 모드이면 생성 후 대상에서 제거한다. 작업 중 sheet 종료·중복 실행을 제한한다. 프롬프트 원문은 reference의 SentencePrompts, 저장 순서는 VocabularyListViewModel을 따른다.

## FR-VOC-05. 신규 생성

`+ 새 단어`는 여러 블록을 받을 수 있다. 빈 줄로 블록을 구분하고 첫 줄은 text, 이후 줄은 `ko: 뜻` 등 번역이다. 아포스트로피를 정규화한 후 블록별 `POST /admin/vocabularies {text,lesson_id?,translations}`. 레슨에서 진입했으면 해당 lesson_id를 사용한다. 실패 시 앞서 생성한 블록은 남는다. `+ 여러 개 추가`는 별도 버튼이 있으나 연결 화면이 빈 Text인 미구현 상태다. 이 버튼과 실제 블록 생성을 혼동하지 않는다.

## FR-VOC-06. 상세 조회·기본 저장·삭제

Vocabulary, 연결 예문, Sense/Form 메타데이터를 불러온다. text, 번역, example_exercise·vocabulary_exercise·is_form 플래그를 편집한다. 저장은 기존 연결 ID를 보존하고 번역 편집 내용을 파싱한 뒤 en-US text 번역을 추가하여 `PUT /admin/vocabularies/{id}`. 삭제는 해당 Vocabulary의 DELETE이며 Word 삭제와 다르다. 성공 메시지·오류를 표시한다.

## FR-VOC-07. 레슨·Sense·Form 변경

- Unit 연결: 양의 정수 Unit으로 Lesson을 조회하고 첫 결과에 현재 Vocabulary를 연결한 뒤 다시 읽는다. 레슨 미발견은 오류다.
- sense_id 직접 입력 적용 또는 펼친 Sense 목록에서 선택 가능하다. 선택 Sense가 현재 Form과 다른 Word에 속하면 Form 해제를 의도한다.
- Form 목록에서 선택 가능하다. 선택 Form이 현재 Sense와 다른 Word에 속하면 Sense 해제를 의도한다.
- Form “해제”는 명시적 form_id=null을 보내되 다른 필드를 보존한다. Sense/Form 교체의 null 전송 결함 가능성은 19번 문서에 구분한다.

## FR-VOC-08. 예문 신규·편집·연결 해제

현재 실제 진입점은 “새 예문 추가” 하위 화면(06번 FR-SEN-06)이다. 별도의 inline 신규 입력과 대표 문장 편집 ViewModel 로직도 존재한다. inline 로직은 Example(vocabulary_id=현재ID)를 먼저 만들고 그 ID로 ExampleSentence를 만든 뒤 부모 재조회·목록 맨 앞 추가·입력 초기화를 수행한다. 편집 로직은 대표/첫 ExampleSentence의 text·translations만 PUT한다. 다만 inline 추가 Section과 편집 진입은 현재 body에 연결되지 않은 코드이므로 실제 노출 기능과 구분한다. 실제 기존 문장 편집은 문장 상세로 들어간다. 항상 보이는 연결 해제(detatch)는 `PUT /admin/examples/{exampleId} {vocabulary_id:null}`이고 예문 실제 삭제가 아니다.

## FR-VOC-09. 기존 예문 검색·연결

상세의 예문 영역에서 “예문 검색·연결”을 열어 검색한다. 현재 text를 기본 검색어로 삼는다. 검색 조건은 예문 문장 화면과 동일한 문장 검색 API다:

1. `GET /admin/example-sentences/search?q=<trim>&limit=50&offset=0`.
2. 결과의 example_id를 중복 제거·정렬하여 부모를 GET한다.
3. 검색 결과 문장 순서에 맞춰 부모 Example을 한 번씩 표시하고 이미 연결된 Example ID는 제외한다.
4. `vocabulary_id=null`인 예문도 배제하지 않는다. `/admin/examples/search`로 대체하지 않는다.
5. 행의 연결은 `PUT /admin/examples/{id} {vocabulary_id:현재VocabularyID}`. 성공 결과를 상세 목록에 추가하고 후보에서 제거한다.

부모 Example의 FK를 바꾸므로 한 부모의 모든 문장에 적용되며 기존 다른 Vocabulary의 연결을 옮길 수 있다. 다대다 attach 테이블을 새로 만들지 않는다. 연결 중 ID별 비활성화·실패 오류·검색 결과 없음·닫기를 제공한다.

## AC-VOC

1. q=apple, Level=2, Unit=10을 입력하면 세 조건이 함께 전송된다. Level=abc는 요청하지 않는다.
2. 검사 버튼은 GET만 사용하고 적용 버튼을 눌러야 PUT한다. 기대 FK 없음은 null로 지워진다.
3. `beautiful plants and animals`가 null Vocabulary 부모 밑 문장이어도 연결 검색에 나온다.
4. 같은 Example의 문장 2개가 검색되어도 연결 후보는 1개다. 다른 이미 연결된 예문은 중복되지 않는다.
5. 연결 해제 뒤 예문 문장 검색에서 원문을 계속 찾을 수 있다.

근거: `LessonClient/UI/Vocabulary/`, `LessonClient/Domain/UseCase/Vocabulary/VocabularyLinkAuditUseCase.swift`, `LessonClient/DataSource/VocabularyDataSource.swift`, `LessonClient/DataSource/ExampleDataSource.swift`.
