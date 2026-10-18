# 11. Form(메뉴 표시: 포럼)

## FR-FRM-01. 목록·검색·선택

Form 검색어와 word_id를 제공한다. word_id가 있으면 해당 Word의 Form 전용 조회가 우선하며 q 검색과 AND로 합치지 않는다. 일반 `/admin/word-forms?q&limit=50&offset`, Word 지정 `/admin/word-forms/by-word/{wordId}`. 숫자만 입력 유지. 초기화는 q·word_id를 비우고 재조회한다. 표는 Form·Type·Word ID·Form ID. 다음 페이지·다중 선택 가능.

## FR-FRM-02. 삭제·편집 상태

개별 행 삭제 또는 선택 행들 삭제는 해당 Form DELETE 후 성공한 행을 제거한다. Edit는 정확히 1개 선택일 때만 활성화한다. 다만 현재 FormListView가 FormEditorSheet를 실제 표시하도록 연결하지 않아 버튼을 눌러도 편집 화면이 열리지 않는 결함이 있다. 편집 sheet의 로직 자체는 존재하므로 미연결 기능으로 기록하고 자동으로 완성된 기능이라고 판정하지 않는다.

## FR-FRM-03. 블록 입력·미리보기·저장

Add Forms 화면의 입력 예:

```text
word: plant
form: plants
form_type: plural

word: go
form: went
form_type: past
```

입력 후 약 250ms debounce 파싱. word와 form은 필수, form_type은 선택이며 추가 explain은 저장 대상이 아니다. 블록별 ready/failed/saved/skipped 상태와 메시지를 미리보기로 보여준다. 저장은 Word를 lemma로 찾고, form 표면형의 별도 Word도 있으면 derived_word_id를 연결한다. `POST /admin/word-forms {word_id,form,form_type?,derived_word_id?}`. 저장 가능한 항목만 실행하고 건별 상태를 갱신한다. 부모 Word를 찾지 못하면 새 Word를 임의 생성하지 않는다. parser 정확 규칙은 reference의 FormBlocksParser다.

## FR-FRM-04. 단어 하나 AI 생성

입력 Word로 Form 프롬프트 호출 → 결과를 동일 블록 형식으로 파싱 → 저장. 결과 문자열을 사용자 화면에도 보여준다. 지원 활용형은 base, past, past_participle, present_participle, 3sg, plural, comparative, superlative를 기본 프롬프트 계약으로 한다. 모든 언어에 강제로 이 규칙을 적용하는 기능은 아니다.

## FR-FRM-05. Form 없는 Word 자동 처리

`GET /admin/words/no-forms`로 후보를 읽고 공백·아포스트로피 포함 Word와 로컬 lemma가 원형과 다른 Word를 제외한다. 대상 snapshot을 만든 뒤 Word별 AI 생성·파싱·저장을 순차 반복한다. 현재 후보 조회 시작 offset=20, limit=200인 점은 19번 문서에 제약으로 남긴다. 진행 Word·결과·실패를 표시하며 실패 항목은 다음으로 계속한다. 수동 현재 Word 생성/다음 이동 제어도 제공한다. 기존 Form을 모두 지우는 배치 재생성과는 다른 기능이다.

## AC-FRM

1. word 키 자체가 없는 블록은 skipped, word 키가 있으나 빈 문자열이면 failed이고 POST하지 않는다.
2. word_id 조건이 있으면 q 검색 결과를 섞지 않는다.
3. Form 단어 Word가 없더라도 부모 Word가 있으면 derived_word_id 없이 생성 가능하다.
4. 한 단어 AI 실패가 전체 자동 작업 성공으로 표시되지 않는다.
5. UI 미연결 Edit 상태를 실제 작동하는 편집 기능으로 검수 통과시키지 않는다.

근거: `LessonClient/UI/Form/`, `LessonClient/DataSource/WordFormDataSource.swift`, `LessonClient/AI/Prompts/FormPrompts.swift`.
