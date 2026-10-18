# 00. 공통 요구사항

## 데이터 구분

| 개체 | 의미와 관계 |
|---|---|
| Lesson | Unit·Level·Track·Topic·Grammar와 학습 단어를 묶는다. ID와 Unit은 별개다. |
| Vocabulary | 레슨에서 학습할 표면형. `text`, `lesson_id`, `form_id`, `sense_id`, `phrase_id`, 번역과 문제 생성 플래그를 가진다. 화면의 “학습 단어”다. |
| Word | 사전 표제어. `lemma`, `normalized`, `kind`와 여러 Sense·Form·발음을 가진다. Vocabulary와 ID 공간을 공유하지 않는다. |
| WordSense | Word의 의미. `sense_code`, `pos`, `cefr`, `explain`, 다국어 뜻·설명과 예문 연결을 가진다. |
| WordForm | Word의 활용형. `word_id`, `form`, `form_type`, 선택적 `derived_word_id`다. |
| Phrase | 여러 단어 또는 고정 구문. `text`, `normalized`, 번역을 가진다. |
| Example | 예문 묶음의 부모. `vocabulary_id`는 null일 수 있다. 여러 ExampleSentence 및 Sense 연결을 가질 수 있다. |
| ExampleSentence | 실제 문장. `example_id`, `text`, `order`, `type`, 번역, 토큰, 연결 문제를 가진다. |
| SentenceToken | 문장 안 표면형/구문. 순서·문자 범위와 Word/Form/Sense/Phrase 연결, 번역을 가진다. |
| Exercise | 부모 Example 및 대상 문장들과 연결된다. 유형·prompt·보기·정답·빈칸을 가진다. |

## FR-COM-01. 통신

- 기본 개발 서버는 `http://127.0.0.1:8000`. 이 주소를 운영 서버라고 가정하지 않는다. 재구현 시 환경 설정으로 주입한다.
- 인증 요청 외 관리자 요청에 `Authorization: Bearer <access_token>`를 전달한다. 토큰은 로그인 응답의 `access_token`이다.
- JSON 요청과 form-urlencoded 로그인을 구분한다. JSON 키는 API의 snake_case를 사용한다.
- HTTP 2xx만 성공이다. DELETE의 빈 응답은 JSON 파싱 오류로 처리하지 않는다. 비성공 상태·네트워크·디코딩 오류를 화면 오류로 보여준다.
- query의 빈 선택 조건은 생략한다. 단, 문장 검색의 q는 빈 문자열도 전송한다. 필수값·양수 조건은 각 기능 문서에 따른다.
- `null`, 키 누락, `[]`는 같지 않다. 특히 연결 해제는 명시적 null, 변경하지 않을 필드는 누락, 번역 전체 비우기는 API가 허용하는 명시적 빈 배열을 구분한다.
- 날짜는 ISO8601(소수 초 유무 모두), 기존 Swift decoder가 지원하는 숫자 날짜 형식을 고려한다. 숫자의 기준 시각을 임의로 Unix로 바꾸지 않는다.

## FR-COM-02. 작업 상태

조회 중/저장 중/삭제 중/일괄 처리 중 상태를 분리한다. 해당 작업이 진행 중이면 중복 실행을 막는다. 단건 작업은 ID별 진행 상태를 사용하여 다른 행과 혼동하지 않는다. 성공 후 서버 응답 또는 재조회 값으로 화면을 갱신한다. 실패한 행은 성공한 것처럼 제거하지 않는다.

일괄 작업은 다수의 HTTP 요청으로 구성되며 전체 트랜잭션이 아니다. 실패 이전 저장·삭제는 남을 수 있다. 작업별 중단/계속 규칙, 진행 건수·오류를 표시한다. 자동 rollback·복구를 임의로 약속하지 않는다.

## FR-COM-03. 다국어·텍스트

- 일반 번역 입력은 `언어코드: 번역`을 줄별로 받는다. 첫 `:`를 구분자로 사용하여 본문 속 `:`를 보존한다. 실제 파서가 다르면 해당 기능의 형식을 우선한다.
- Lesson 번역은 `{lang_code, topic}`이며 일반 `{lang_code, text}`와 다르다. Sense 번역에는 `explain`이 추가된다. SentenceToken 번역은 `lang` 키다.
- 기본 한국어 표시는 ko 계열, 영어는 en-US 등 원본 언어 식별자를 유지한다. 임의로 모든 `en`을 `en-US`로 치환하지 않는다.
- 아포스트로피 정규화·대소문자/악센트 무시 비교는 “동일 단어 찾기”에 사용하며 사용자 표시 문자열을 전부 소문자로 덮지 않는다.
- 정렬은 기능별 규칙을 따른다. 서버가 정렬하는 목록을 클라이언트가 임의로 가나다 정렬하지 않는다.

## FR-COM-04. 보안·운영 보호

문서·로그·클라이언트 저장소에 API 키, 비밀번호, access_token을 복제하지 않는다. AI·Google TTS 자격 증명은 외부 설정/안전한 중계로 공급한다. 기존 코드의 하드코딩은 재현 요구사항이 아니다. 테스트는 fixture·mock을 우선하며 운영 데이터 수정은 별도 승인 없이 실행하지 않는다.

## AC-COM

1. Example와 Sentence, Vocabulary와 Word가 같은 숫자 ID여도 서로 다른 API 대상으로 처리된다.
2. 연결 해제 요청에는 해당 FK가 null로 포함되고, 다른 필드가 지워지지 않는다.
3. 401·404·409·422·500·timeout·잘못된 JSON을 모의하여 로딩이 종료되고 오류를 확인할 수 있다.
4. 일괄 3건 중 2번째 실패 시 이미 성공한 1번째를 유지하고 해당 기능의 계속/중단 규칙을 따른다.

근거: `LessonClient/API/APIClient.swift`, `LessonClient/Models/`, `LessonClient/DataSource/`, `LessonClient/UI/Data/Models+Extension.swift`.
