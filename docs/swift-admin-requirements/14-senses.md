# 14. Sense

## FR-SNS-01. 목록·검색·페이지

`GET /admin/words?q&limit=50&offset`로 Word 페이지를 가져온 뒤 Sense를 펼쳐 행으로 만든다. 서버에 독립 Sense 전체 검색 API를 호출하는 구조가 아니다. 로컬 필터는 lemma·normalized·kind·sense_code·pos·cefr·explain·번역을 q와 비교한다. 단, 서버의 Word q 필터 이후 처리하므로 전체 DB의 번역 검색을 보장하지 않는다. 정렬은 lemma→sense_code. 행은 Sense 상세로 이동하며 생성 화면·누락 Sense 도구를 제공한다. Sense 없는 Word 페이지일 때 추가 로드가 멈출 수 있는 제약은 19번에 기록한다.

## FR-SNS-02. 블록 파싱·미리보기

```text
word: plant
sense: a living thing that grows in soil
pos: noun
cefr: A1
ko: 식물
example: This is a plant.

word: plant
sense: to put a plant in the ground
pos: verb
cefr: B1
ko: 심다
example: We plant flowers.
```

빈 줄 블록, 첫 콜론 key/value, key 소문자 비교, 아포스트로피 정규화. 각 블록의 sense·pos·cefr·ko는 비어 있지 않아야 한다. example은 파서상 선택(없으면 빈 문자열). 전체 head word가 있어야 한다. 알 수 없는 키와 콜론 없는 줄은 무시한다. 미리보기에는 head와 Sense 개수 또는 구체적 파싱 오류를 표시한다. 현재 parser는 블록 간 word 불일치를 검사하지 않으므로 동일 Word 블록으로 입력해야 한다.

## FR-SNS-03. 저장

head Word를 lemma로 찾아 없으면 생성한다. 기존 Sense가 하나라도 있는 Word는 이 생성 화면에서 추가하지 않고 종료하는 현재 제약이 있다(단일 추가는 Word 상세). Sense 없는 Word에 입력 순서대로 s1, s2… 생성한다. explain=sense, pos, CEFR 대문자, 번역=[{lang:"ko",text:ko,explain:""}]. 각 Sense마다 Vocabulary 미연결 Example 생성 → ExampleSentence(example text) 생성 → is_prime=true로 Sense 예문 연결. 실패 시 앞선 Sense·예문은 남고 실패 상태를 표시한다. example이 선택이어도 후속 저장은 빈 문장을 거절할 수 있으므로 파싱 성공과 저장 성공을 구분한다.

## FR-SNS-04. 상세·수정·삭제

Sense와 Word, `/admin/examples/by-sense/{senseId}` 예문을 읽는다. 예문 조회가 불가능하면 내장 sense.examples를 보완 사용한다. Word 상세·각 문장 상세로 이동한다.

편집: sense_code와 explain 필수, pos·cefr 선택, CEFR 대문자. 다국어 뜻과 설명은 각각 언어코드:본문 입력을 받으며 언어 집합을 합쳐 `{lang,text,explain}`로 만든다. PUT `/admin/words/senses/{id}` 후 최신 응답 반영. 삭제 확인 후 Sense DELETE, 성공 시 복귀. Word 자체는 삭제하지 않는다.

## FR-SNS-05. 누락 Sense 후보·자동 생성

`GET /admin/examples/without-sense-tokens?limit=200`에서 예문을 읽고 대표 문장을 로컬 형태소 분석하여 lemma 후보를 만든다. 공백 없는 문자 단어를 중복 제거하고 사전 조회 결과 없는 후보를 표시한다. 현재 try? 조회 오류도 없는 Word로 오인할 수 있으므로 오류와 미존재 구분은 19번 결정사항이다. 선택/입력 후보에 자동 생성 use case를 실행한다.

자동 생성 공통 흐름: AI로 lemma 정리 → 단일 raw 입력이 제외됐을 때 독립 Word 여부 Y/N 확인 → 기존 Word/Sense 조회 → 필요 시 Word·Sense·미연결 예문·Form·Phrase 생성. 이미 Sense가 있으면 Sense 중복 생성 대신 필요한 Form/Phrase를 보강한다. Form은 공백 없는 단어만, 동일 form+type 중복은 제거한다. Phrase 번역은 한국어 뜻들을 중복 없이 ` / `로 결합한다. 정확한 프롬프트·파서·오류 처리의 일부 best-effort 단계는 reference의 AutoGenerateWordSensesUseCase 원문을 따른다.

## AC-SNS

1. ko 없는 블록은 파싱 실패, example 없는 블록은 파싱 가능하다.
2. 2개 유효 블록은 s1·s2로 생성하고 예문 부모는 vocabulary_id 미연결이다.
3. 기존 Sense가 있는 Word에 생성 폼을 제출해도 중복 Sense가 추가되지 않는다.
4. 상세 번역의 뜻만 있는 언어와 설명만 있는 언어가 유실되지 않는다.
5. Sense 삭제가 Word DELETE를 호출하지 않는다.

근거: `LessonClient/UI/Sense/`, `LessonClient/Domain/Parsers/SenseBulkParser.swift`, `LessonClient/Domain/UseCase/WordSense/AutoGenerateWordSensesUseCase.swift`.
