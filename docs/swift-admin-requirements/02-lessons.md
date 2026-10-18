# 02. 레슨

진입: 레슨 메뉴. 목록에서 상세·생성·Insert·일괄 생성 화면으로 이동한다.

## FR-LES-01. 목록·Unit 검색

Unit 입력 후 검색/Enter로 `GET /admin/lessons?unit=<정수>&limit=…`를 호출한다. 목록 화면에 Level 검색 필드는 없다. 초기 진입·초기화는 API 목록의 첫 레슨만 표시하는 현재 동작이다. Unit이 비거나 정수 변환에 실패하면 unit 조건 없이 조회한다(엄격 검증이 아님). 행에는 Unit, 번역 Topic, 학습 단어 등 레슨 요약을 표시하고 상세로 이동한다. Insert 후에는 현재 검색 조건으로 목록을 다시 조회한다.

## FR-LES-02. 새 레슨

입력: Unit·Level(각각 1 이상 정수), 한국어 Topic, Grammar. Level 기본 1. Unit 기본은 조회한 기존 Unit 최댓값+1이며 `nextUnit`은 기본 limit=1 조회 결과에 의존한다. Unit 변경 시 `max(Unit-1,1)` 레슨을 조회해 Topic·Grammar를 자동 채운다. 값이 없으면 빈 문자열이다. Topic 필수 검증은 없다.

저장: `POST /admin/lessons`에 unit, level, 기본 track_code=en-US, grammar(빈 값이면 생략), translations=`[{lang_code:"ko",topic:…}]`. 성공한 레슨을 상위 화면에 반영한다. 저장 중 다시 저장하지 않는다.

## FR-LES-03. 레슨 삽입

목록의 Insert 버튼으로 전용 삽입 화면을 연다. Unit(1 이상 필수), Track Code(기본 en-US, trim 후 필수), Topic·Grammar(선택)를 입력한다. Level 입력과 단순 생성 화면을 혼합하지 않는다.

`POST /admin/lessons/insert`에 unit·track_code와 비어 있지 않은 grammar·한국어 translations를 보낸다. 빈 Topic은 translations를 생략한다. 서버의 삽입 처리를 사용하며 클라이언트가 기존 레슨들을 하나씩 PUT하여 Unit을 이동시키지 않는다. 후속 Unit 이동의 정확한 범위·Level 부여는 서버 계약에 따르며 이 소스만으로 내부 동작을 확정하지 않는다. 성공 후 화면 종료 및 목록 재조회로 변경된 번호를 표시한다.

## FR-LES-04. 여러 레슨 생성

입력: Topic 필수, 시작 Unit 1 이상, 단어 목록 필수. Level=1 고정. 쉼표·세미콜론·줄바꿈으로 나누고 trim·빈 항목 제거한다. 두 단어씩 한 Unit에 넣으며 마지막 홀수 단어도 한 레슨이다. 예상 레슨 수는 ceil(단어수/2).

각 Unit에 기존 레슨이 있으면 재사용하고 없으면 Topic과 함께 생성한다. 단어별로 q 검색 후 정규화한 text가 정확히 같은 Vocabulary를 찾는다. 기존 Vocabulary가 미배정이면 연결하고 다른 레슨에 이미 배정됐으면 이동시키지 않는다. 신규는 Phrase 정확 일치, Form 정확 일치, Form의 Word 또는 입력 lemma의 Sense 중 s1을 조회하여 가능한 연결 ID를 함께 생성한다. Topic·Grammar를 기존 레슨에 강제 덮어쓰지 않는다. 중간 실패는 단어명과 오류를 알리고 중단하며 이전 요청은 유지된다.

## FR-LES-05. 상세 편집·삭제

`GET /admin/lessons/{id}`로 Unit·Level·한국어 Topic·Grammar와 Vocabulary를 채운다. 저장은 현재 연결 Vocabulary ID 목록과 translations를 포함해 `PUT /admin/lessons/{id}`. 현재 상세 검증은 Unit/Level 정수 변환이며 생성 화면과 달리 양수 guard가 없다. 삭제는 `DELETE /admin/lessons/{id}`. 연관 데이터 cascade는 서버 정책을 확인한다.

## FR-LES-06. 레슨의 단어·문제

연결 후보는 `GET /admin/vocabularies/list/unassigned`의 선택적 word 조건으로 조회하며 이미 현재 레슨에 있는 ID는 제외한다. 연결 `POST /admin/lessons/{id}/vocabularies {vocabulary_id}`, 해제 `DELETE /admin/lessons/{id}/vocabularies/{vocabularyId}`. 해제는 Vocabulary 자체 삭제가 아니다. 새 단어 생성 시 현재 lesson_id를 전달한다. 단어 행은 학습 단어 상세로 이동한다.

연습문제 요약은 lesson_targets의 sort_index 순 문제와 Vocabulary 예문 문제를 합쳐 ID 중복 제거한다. 제목은 대상 Vocabulary 이름, 없으면 표시용 prompt 등으로 구성하고 유형·prompt·문제 상세 진입을 제공한다.

## FR-LES-07. 복사

현재 목록의 레슨들을 순서대로 클립보드 텍스트로 내보낸다. Unit, 한국어 Topic, Grammar(없으면 `_`), 단어·번역들, 예문이 있는 단어의 문장·번역들을 포함한다. DB는 변경하지 않는다.

## AC-LES

1. 단어 5개, 시작 U10이면 U10·11·12에 2·2·1개를 처리한다.
2. 다른 레슨에 이미 속한 단어는 일괄 생성에서 뺏어오지 않는다.
3. Insert 요청은 `/insert` 한 번이며 성공 후 기존 목록을 재조회한다.
4. 연결 해제 후 단어 검색에서 Vocabulary 자체는 남는다.
5. Topic JSON에 `text`가 아니라 `topic`을 사용한다.

근거: `LessonClient/UI/Lesson/` 전체, `LessonClient/DataSource/LessonDataSource.swift`.
