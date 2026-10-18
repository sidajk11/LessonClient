# 08. 연습문제

## FR-EXR-01. 전체 검색·표시

연습문제 메뉴는 q·Level·Unit 검색을 제공한다. 숫자 필드는 숫자만 유지하며 빈 조건은 전체다. `GET /admin/exercises/search?q&level&unit&limit=50`(DataSource 상한 200). 검색 후 기존 검사 상태를 비운다. 행은 유형·표시용 prompt·보기·정답 등으로 구성하고 상세로 이동한다.

유형 직렬화: select, select_trans, combine_word, input_word, comprehend. Swift 내부 .combine/.input 명칭을 API 값으로 그대로 보내지 않는다. 표시용 prompt는 대상 문장 token+blanks 구성이 있으면 그것을 우선하고, 없으면 prompt, 문장 텍스트 순으로 보완한다. token_index 순서·빈칸 slot_count(최소 1)를 반영한다. 옵션 표시는 기존 top-level display_text/text와 번역 fallback 규칙을 보존한다.

## FR-EXR-02. 정답 검사

검사는 읽기 전용이며 select·combine만 지원한다. options는 position→id, correct_options도 position→id 순 정렬한다. select는 마지막 보기 하나를 제외한 option ID 배열이 정답 option_id 배열과 순서까지 같아야 한다. combine은 전체 option ID 배열이 정답 배열과 같아야 한다. 다르면 “정답오류”. 전체 검사는 현재 검색 결과 전부에 적용한다. 정답 텍스트 집합 비교로 대체하지 않는다.

## FR-EXR-03. 문장별 문제 목록

현재 하위 연습문제 목록은 부모 Example의 여러 문장 문제를 합쳐 ID 중복 제거·ID 내림차순으로 표시한다. 선택 문장은 생성 화면의 문맥이며 목록 자체를 그 문장만으로 필터하지 않는 현재 구현이다. prefetch 전용 모드에서는 부모의 모든 orderedExampleSentences.exercises를 합친다. 서버 조회 모드는 Example 문제를 조회하고 응답이 비면 prefetch로 보완한다. 각 문제의 대상 문장 텍스트를 함께 보여준다. 문장 검색 화면의 단건 문제 삭제·자동 생성은 정확한 sentence ID로 필터하는 별도 흐름이다. 문제 상세와 추가 화면으로 이동한다.

## FR-EXR-04. 수동 생성

선택한 ExampleSentence를 필수 문맥으로 받는다. 기본 select. 문장 토큰에서 시험 단어를 선택하고 과거 Unit의 학습 단어를 오답으로 선택한다. select는 선택 위치를 `_`로 바꾸고 선택 정답 단어들을 먼저, 선택 오답들을 뒤에 놓아 보기 목록을 만든다. combine 전환은 문장 비문장부호 토큰 순서대로 보기를 구성하고 문장을 빈칸 형태로 보여준다. 유형 선택에 존재하는 다른 유형에 별도 편집 UI가 충분하지 않은 현재 제약을 보존해 보고한다.

생성은 `POST /admin/exercises`에 example_id, target_sentence_ids=[현재 sentence ID], type, prompt, options, translations=[{lang_code:en-US,question:null}]를 전달한다. 문맥상 소문자 사용 가능한 옵션만 소문자 변환한다. correctness를 임의로 별도 PUT하는 흐름을 추가하지 않는다. 생성 결과·실패 오류·중복 제출 방지를 제공한다.

## FR-EXR-05. 누락 문제 자동 생성

1. 부모 Example의 문제 중 target_sentences가 현재 문장인 것을 조회한다.
2. combine이 없으면 생성하고, select가 없고 target Vocabulary가 있으면 select를 생성한다. 기존 유형은 건드리지 않는다.
3. 토큰은 로컬 → 서버 재조회 순으로 원문 범위 일치를 검사한다. 양쪽 다 비어 있을 때만 새 토큰을 만든다. 기존 토큰이 원문과 다르면 staleTokens 오류이며 조용히 삭제·재생성하지 않는다.
4. combine은 모든 비문장부호 토큰을 순서대로 보기로, 원문 문장부호는 유지한 채 나머지를 `_`로 prompt에 넣는다.
5. select는 Phrase/Sense/Form/Word/Vocabulary ID 또는 정규화 text·동일 단어 비교로 target에 대응하는 토큰을 찾는다. 일치 토큰 위치는 모두 빈칸, 정답 표면형은 첫 일치 토큰이다.
6. 현재 Vocabulary Unit 또는 lesson 조회 Unit보다 작은 Vocabulary 목록에서 오답을 뽑는다. 공백 포함 후보, 정답과 같은 단어, 문장에 이미 등장한 단어는 제외한다. 남은 후보에서 무작위 하나를 선택한다. 보기=[정답,오답]. 대상 토큰·Unit·오답 후보가 없으면 명시적 오류다.

정밀 알고리즘은 `reference/GenerateExerciseUseCase.swift`다. 무작위 결과 자체가 아니라 후보 조건을 fixture로 검증한다.

## FR-EXR-06. 상세 보기 편집·삭제

현재 문제의 prompt·유형·보기·정답·대상 정보를 표시한다. select 문제의 보기 편집은 기존 보기와 추가 후보를 toggle하고, 변경 여부를 대소문자 무시 배열 비교로 판정한다. 저장 시 현재 prompt 보존, type=select, 현재 보기 텍스트를 소문자로 변환한 options와 en-US 번역 정보를 PUT한다. 자동 생성의 문맥 기반 소문자화와 상세 편집의 일괄 소문자화는 다르다. 삭제는 확인 후 `DELETE /admin/exercises/{id}`, 성공하면 목록으로 복귀한다.

## AC-EXR

1. select options=[10,11], correct=[10]은 정상, correct=[11]은 정답오류다.
2. combine 보기 순서가 정답과 다르면 같은 ID 집합이어도 오류다.
3. 기존 combine만 있는 문장은 select만 추가한다. Vocabulary가 없으면 select를 만들지 않는다.
4. 과거 Unit 오답 후보 없음은 오류이며 미래 Unit 단어로 대체하지 않는다.
5. 형제 문장용 문제는 현재 문장의 누락 여부 판단에 쓰지 않는다.

근거: `LessonClient/UI/Exercise/`, `LessonClient/Domain/UseCase/Exercise/`, `LessonClient/Models/`의 Exercise 관련 모델, `LessonClient/DataSource/ExerciseDataSource.swift`.
