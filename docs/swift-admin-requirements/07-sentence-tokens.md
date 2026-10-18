# 07. 문장 토큰

진입: 예문 문장 상세의 토큰 영역 → 토큰 상세. 독립 SentenceTokenListView도 존재하지만 현재 MainTab에는 없다. 리스트를 최상위 메뉴 기능으로 오인하지 않는다.

## FR-TOK-01. 생성·구문 병합·범위

빈 문장 거절 → 정규식 토큰화 → 캐시된 Phrase와 일치하는 연속 토큰을 긴 구문 우선 병합 → surface·phrase_id 초안 생성. 단순 split(" ")로 대체하지 않는다. token_index는 0부터 연속이다. 원문에서 앞쪽 cursor 이후 surface를 대소문자 구분하여 찾고 사이·마지막 잔여 문자열은 공백만 허용한다. 범위는 Swift NSString과 호환되는 UTF-16 code unit 기준, start 포함/end 제외다. 반복되는 같은 단어는 앞에서부터 각각 다른 범위를 갖는다. 생성은 `POST /admin/sentence-tokens`를 토큰별 호출한다.

첫 생성은 기존 토큰이 없을 때 동작한다. 기본 생성은 phrase_id와 범위를 채우고 form_id는 nil이다. 이 작업만으로 모든 토큰에 Sense가 자동 배정된다고 가정하지 않는다. 정확한 tokenizer·구문 우선순위는 reference 원문을 따른다.

## FR-TOK-02. 재생성·전체 삭제

상세 “토큰 재생성”은 원문으로 새 초안을 만들고 기존 토큰 token_index 순 배열과 위치별로 대응한다. min(기존 수,초안 수)만 PUT하고 기존 ID·기존 sense_id, 기존 phrase/form이 있으면 그것을 보존한다. word_id·pos는 null로 초기화한다. 기존 토큰이 더 많으면 남는 토큰은 그대로, 초안이 더 많으면 남는 초안은 생성하지 않는다. surface가 같은 것을 찾아 대응하는 알고리즘이 아니며 문장 변경 후 의미 연결이 잘못 보존될 수 있다. 이 제약은 19번에도 기록한다.

별도 전체 재생성 경로는 기존 토큰을 지우고 다시 생성하며 includePhrases=false 경로도 있다. UI에 연결된 동작과 내부 함수만 있는 동작은 구분한다. “토큰삭제”는 현재 선택 문장의 토큰만 삭제한다. 이후 부모 재조회·선택 문장 갱신·뜻 재계산. 처리 실패 시 부분 삭제/생성이 남을 수 있다.

## FR-TOK-03. 표시·복사

행은 token_index 순으로 index, surface, token ID, Phrase/Word/Form/Sense ID, start~end, Vocabulary 연결, ko 뜻과 토큰 번역을 보여준다. 뜻은 연결 Sense/Phrase 및 자체 번역을 조회해 구분한다. “전체 복사”는 문장 및 token_id·연결 후보 Sense가 들어간 LLM 작업 텍스트를 만든다. “번역 할 토큰 복사”는 문장부호를 제외한 토큰의 번역 작업용 블록을 복사한다. 복사는 DB를 바꾸지 않는다.

## FR-TOK-04. Sense 일괄 할당

입력 예:

```text
token: plants
token_id: 101
sense_id: 205

token_id: 102
sense_id: 206
```

빈 줄로 블록을 나눈다. token은 참고값, token_id/tokenid 및 sense_id/senseid 허용. ID는 1 이상. 알 수 없는 키·숫자 오류는 거절한다. 완성된 쌍이 없으면 오류. 현재 문장에 없는 token ID는 저장 전에 모두 검증하여 거절한다. 같은 token ID가 반복되면 마지막 sense ID를 사용한다. Sense를 GET하여 word_id를 확보한 후 token에 word_id와 sense_id를 함께 PUT한다. 성공 후 sheet 닫기·부모 재조회. 네트워크 중간 실패는 앞선 적용을 자동 rollback하지 않는다.

## FR-TOK-05. 번역 일괄 입력

```text
token_id: 101
token: plants
ko: 식물들
es: plantas
```

빈 줄 블록, token_id/tokenid는 양의 정수, token은 무시하고 나머지 키는 언어코드다. 빈 번역은 저장하지 않는다. 각 언어를 `PUT /admin/sentence-tokens/{id}/translations {lang,text}`로 upsert한다. 이 방식은 입력에 없는 기존 언어를 삭제하지 않는다. 현재 문장에 없는 token ID는 제외하고 결과로 알린다(Sense 할당의 전체 사전 거절과 다름). 성공 후 다시 읽는다.

## FR-TOK-06. 단건 편집

`GET /admin/sentence-tokens/{id}`. 필수 exampleSentenceId≥1, tokenIndex≥0, trim surface 비어 있지 않음. 선택 phraseId/wordId/formId/senseId는 비면 null, 있으면≥1. startIndex/endIndex는 비면 null, 있으면≥0. pos는 빈 값 null. 저장은 전체 필드 PUT로 null 연결을 명시하며 응답으로 입력을 재바인딩한다. 현재 end≥start와 원문 일치의 추가 저장 검증은 없다. 번역·연관 개체 정보를 별도로 표시한다.

## FR-TOK-07. 소스에 존재하는 토큰 목록

exampleSentenceId·phraseId·wordId·formId·senseId 선택 필터로 목록을 검색한다. 양의 정수 검증, limit/offset 페이지 추가, 상세 이동·행 삭제를 제공한다. MainTab 진입점은 미연결 상태로 기록한다. 재구현 시 독립 메뉴를 추가할지는 별도 결정사항이다.

## AC-TOK

1. `I see plants.`는 문장부호를 포함한 순서와 범위를 보존한다. 같은 `my`가 두 번 나오면 같은 위치에 중복 매핑하지 않는다.
2. `😀 apple`의 apple 범위는 Unicode 코드포인트 수가 아니라 UTF-16 기준이다.
3. 잘못된 surface·누락 문자·남은 문장부호는 범위 계산 실패다.
4. 잘못된 token ID는 Sense 할당에서 PUT 0회, 번역 할당에서는 제외 메시지로 처리한다.
5. 빈 Form ID를 저장하면 이전 Form이 유지되지 않고 null이 된다.

근거: `LessonClient/UI/SentenceToken/`, `LessonClient/UI/ExampleSentence/Detail/`, `LessonClient/Domain/Example/SentenceTokenPhraseMerger.swift`, `LessonClient/Domain/UseCase/ExampleSentence/`, `LessonClient/Utils/`.
