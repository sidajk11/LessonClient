# 18. API·데이터 계약 부록

서버 기본 URL은 별도 설정이다. 아래는 Swift가 사용하는 계약이며 현재 서버 지원을 실시간 검증한 문서가 아니다. 각 API의 정확한 선택 필드·기본값·CodingKeys는 `reference/*DataSource.swift`와 모델 사본을 함께 읽는다. 아래 표의 q 등은 query parameter, `{…}`는 JSON body다. CRUD가 DataSource에 있다는 사실은 동일한 UI가 있다는 뜻이 아니다.

## 인증

| 목적 | 요청 | 응답/후속 |
|---|---|---|
| 가입 | POST `/app/v1/auth/join` `{email,password}` | User, 이어서 로그인 |
| 로그인 | POST `/app/v1/auth/login`, form `username,password,grant_type=password,scope=` | access_token 저장 |
| 사용자 복구 | GET `/admin/users/me` | User |

## 레슨·유닛 레벨

| 목적 | 요청 |
|---|---|
| 목록 | GET `/admin/lessons` query `level?,unit?,limit=10` |
| 다음 Unit | 위 목록을 limit=1로 읽고 결과 max(unit)+1 |
| 생성 | POST `/admin/lessons` `{unit,level,track_code,grammar?,translations?,vocabulary_ids?,lesson_targets?}` |
| 삽입 | POST `/admin/lessons/insert` `{unit,track_code,grammar?,translations?,vocabulary_ids:[]}`; level을 필수로 추가하지 않는다 |
| 단건·수정·삭제 | GET/PUT/DELETE `/admin/lessons/{id}` |
| 단어 연결 | POST `/admin/lessons/{id}/vocabularies` `{vocabulary_id}` |
| 단어 해제 | DELETE `/admin/lessons/{id}/vocabularies/{vocabularyId}` |
| Unit Level 목록 | GET `/admin/unit-levels` query `level?,start_unit?,limit,offset` |
| Unit Level 쓰기 | POST `/admin/unit-levels`, PUT/DELETE `/admin/unit-levels/{id}`, 쓰기 `{level,start_unit}` |

Lesson의 translations는 `[{lang_code:"ko",topic:"…"}]`. Lesson에 Unit·Level·track_code와 연결 vocabularies·lesson_targets가 포함될 수 있다. UI가 기대하는 문제 요약은 두 연결 경로를 합쳐 ID 중복 제거한다.

## Vocabulary

| 목적 | 요청 |
|---|---|
| 목록 | GET `/admin/vocabularies` query `level?,unit?,limit<=600,offset` |
| 검색 | GET `/admin/vocabularies/search` query `q?,level?,unit?,langs?,limit=30` |
| 미배정 | GET `/admin/vocabularies/list/unassigned` query `word?,limit<=200` |
| 예문 없음 | GET `/admin/vocabularies/list/without-examples` query `limit<=600,offset` |
| 이전 Unit | GET `/admin/vocabularies/list/unit-lt` query `unit_lt` |
| Word/Form/Sense 기준 | GET `/admin/vocabularies/by-word/{id}`, `/by-form/{id}`, `/by-sense/{id}` query `limit,offset` |
| Word+CEFR | GET `/admin/vocabularies/filter/by-word-cefr` query `word_id,cefr,limit,offset` |
| Sense/Form 조건 | GET `/admin/vocabularies/filter/by-sense` query는 원문 DataSource 확인 |
| 생성 | POST `/admin/vocabularies` |
| 단건·수정·삭제 | GET/PUT/DELETE `/admin/vocabularies/{id}` |

쓰기 필드: `text,lesson_id,form_id,sense_id,phrase_id,example_exercise,vocabulary_exercise,is_form,translations`. 번역 `[{lang_code,text}]`. 관련 필드를 보존할 때는 현재 값을 함께 전달한다. replaceVocabulary 경로는 FK에 NSNull을 넣지만 updateVocabulary의 Optional nil은 인코딩에서 누락될 수 있다. 두 메서드를 동등하게 취급하지 않는다.

## Example·ExampleSentence·Token

| 목적 | 요청 |
|---|---|
| 부모 검색 | GET `/admin/examples/search` query `q,level?,unit?,limit<=400` |
| Vocabulary/Sense/Phrase 예문 | GET `/admin/examples/by-vocabulary/{id}`, `/by-sense/{id}`, `/by-phrase/{id}` query `limit<=200` |
| Sense 없는 토큰 예문 | GET `/admin/examples/without-sense-tokens?limit<=200` |
| 부모 생성 | POST `/admin/examples` `{vocabulary_id?}` |
| 부모 단건·삭제 | GET/DELETE `/admin/examples/{id}` |
| 부모 Vocabulary 연결·해제 | PUT `/admin/examples/{id}` `{vocabulary_id:<id 또는 null>}` |
| 문장 목록 | GET `/admin/example-sentences` query `example_id?,limit<=500,offset` |
| 문장 검색 | GET `/admin/example-sentences/search` query `q,example_id?,level?,unit?,limit<=500,offset` |
| 다중 문장 | GET `/admin/example-sentences/multi-sentence` query `example_id?,level?,unit?,limit<=500,offset` |
| 문장 생성 | POST `/admin/example-sentences` `{example_id,text,order?,type?,speaker_name?,translations?}` |
| 문장 단건·수정·삭제 | GET/PUT/DELETE `/admin/example-sentences/{id}` |
| 문장 번역 전체 치환(DS 제공) | PUT `/admin/example-sentences/{id}/translations` |
| Token 목록 | GET `/admin/sentence-tokens` query `example_sentence_id?,phrase_id?,word_id?,form_id?,sense_id?,limit<=500,offset` |
| Token 생성 | POST `/admin/sentence-tokens` |
| Token 단건·수정·삭제 | GET/PUT/DELETE `/admin/sentence-tokens/{id}` |
| Token 번역 upsert | PUT `/admin/sentence-tokens/{id}/translations` `{lang,text,is_primary:true}` |

ExampleSentence 최소 읽기 필드: id, example_id, text. order 미제공 시 0, type 미제공 시 sentence, 번역/토큰 등 배열은 모델별 기본값을 따른다. 번역은 `[{lang_code,text}]`. 부모 Example의 표면 sentence 계산과 실제 문장 ID를 구분한다.

Token 쓰기: `example_sentence_id,token_index,surface,phrase_id,word_id,form_id,sense_id,pos,start_index,end_index`. 전체 replace는 nullable 필드를 null로 포함한다. 토큰 자체 번역의 언어 키는 `lang`이다. 범위는 UTF-16 start 포함/end 제외다.

## Exercise·운영 기록

| 목적 | 요청 |
|---|---|
| 문제 목록 | GET `/admin/exercises` query `example_id?,vocabulary_id?,limit<=200` |
| 문제 검색 | GET `/admin/exercises/search` query `q,level?,unit?,limit<=200` |
| 생성 | POST `/admin/exercises` `{example_id,target_sentence_ids,type,prompt,options,translations,…}` |
| 단건·수정·삭제 | GET/PUT/DELETE `/admin/exercises/{id}` |
| 부분 치환(DS 제공) | PUT `/admin/exercises/{id}/options`, `/translations`, `/expected-answers`, `/correct-options` |
| 시도 기록 | GET `/admin/exercise-attempts` query `user_id?,exercise_id?,is_correct?,limit<=500,offset`; DELETE `/{UUID}` |
| 학습 큐 | GET `/admin/exercise-queues` query `user_id?,batch_id?,exercise_id?,consumed?,limit<=500,offset`; DELETE `/{id}` |
| 단어 상태 | GET `/admin/user-vocabulary-states` query `user_id?,vocabulary_id?,limit<=500,offset`; DELETE `/{id}` |

Exercise의 type은 combine_word/input_word 등 서버 문자열이다. 보기의 position, correct_options의 option_id·position, target_sentences의 example_sentence_id를 보존한다. 부모 Example ID만으로 문장별 문제를 식별하지 않는다. exact option payload는 reference의 Exercise DTO를 따른다. 기록 3종의 생성·단건·수정도 DS에 있으나 UI 요구 범위는 조회·삭제다.

## Word·Sense·Form·Phrase·발음

| 목적 | 요청 |
|---|---|
| Word 목록·생성 | GET `/admin/words` query `q?,kind?,limit<=200,offset`; POST `{lemma,kind:"WORD"}` |
| 단건·수정·삭제 | GET/PUT/DELETE `/admin/words/{id}` |
| lemma 단건 | GET `/admin/words/by-lemma?lemma=…` |
| 단어 검색 단건 | GET `/admin/words/search?word=…` |
| Form 없는 Word | GET `/admin/words/no-forms?limit<=200&offset` |
| Word의 Sense | GET `/admin/words/{wordId}/senses?limit<=500&offset`; POST 같은 경로 |
| Sense 단건·수정·삭제 | GET/PUT/DELETE `/admin/words/senses/{id}` |
| lemma별 Sense | GET `/admin/words/senses/by-lemma?lemma&limit&offset`, `/by-lemma-cefr?lemma&cefr&limit&offset` |
| Sense 예문 연결 | POST `/admin/words/senses/{id}/examples` `{example_id,is_prime}` |
| Sense 번역 upsert | PUT `/admin/words/senses/{id}/translations` `{lang,text,explain}` |
| Form 목록 | GET `/admin/word-forms` query `word_id?,form_type?,q?,limit<=200,offset` |
| 표면형별 Form | GET `/admin/word-forms/by-form?form&limit&offset` |
| Word별 Form | GET `/admin/word-forms/by-word/{id}?limit&offset` |
| Form 생성·단건·수정·삭제 | POST `/admin/word-forms`, GET/PUT/DELETE `/admin/word-forms/{id}` |
| Phrase 목록·생성 | GET `/admin/phrases?q&limit&offset`; POST `{text,translations?}` |
| Phrase 단건·수정·삭제 | GET/PUT/DELETE `/admin/phrases/{id}` |
| 발음 목록 | GET `/admin/pronunciations` query `word_id?,sense_id?,dialect?,limit<=200,offset` |
| 발음 생성·단건·수정·삭제 | POST `/admin/pronunciations`, GET/PUT/DELETE `/admin/pronunciations/{id}` |

Sense 쓰기: `sense_code,explain,pos,cefr,translations:[{lang,text,explain}]`. Form: `word_id,derived_word_id,form,form_type,translations:[{lang,explain}]`(Form 번역은 일반 text가 아니다). Phrase: `text,translations:[{lang,text}]`. Pronunciation: `word_id,sense_id,dialect,ipa,is_primary` 및 DS의 추가 선택 필드. optional 필드 누락/명시적 null은 DTO 원문을 따른다.

## 구현 시 고정 fixture 예

- V1: Vocabulary id=101, text=plants, lesson_id=10, form_id=501, sense_id=601.
- W1: Word id=201, lemma=plant, Form id=501, Sense id=601. Word와 Vocabulary ID는 반드시 다르게 둔다.
- E1: Example id=301, vocabulary_id=null, Sentence id=401 text=`beautiful plants and animals`; E1의 다른 Sentence id=402도 추가한다.
- L1/L2: Unit 8/12. 각 단어 해석을 별도로 stub하여 최고값을 검사한다.
- 문제는 E1 아래 S401 전용·S402 전용·두 문장 공통을 모두 둔다.
- HTTP 성공 fixture만 만들지 말고 404,409,422,500, malformed JSON과 중간 일괄 실패도 둔다.

이 숫자들은 테스트용 예시이며 운영 레코드 ID가 아니다. 요청 필터와 대상 ID까지 검증해야 기능 동등성을 판단할 수 있다.
