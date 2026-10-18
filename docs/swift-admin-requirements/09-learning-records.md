# 09. 시도 기록·학습 큐·단어 상태

세 메뉴는 별도 화면이며 검색/조회·페이지·삭제가 주 기능이다. DataSource에 생성·수정 메서드가 존재한다는 이유로 해당 관리자 UI가 있다고 판단하지 않는다.

## FR-ATT-01. 시도 기록 검색·표시

User ID·Exercise ID 선택 입력, 정답 여부 전체/정답/오답을 제공한다. ID는 빈 값이면 생략, 있으면 양의 정수 검증. 정답 여부는 전체일 때 생략하고 현재 Swift 계약에서는 `is_correct=true/false`. `GET /admin/exercise-attempts?user_id&exercise_id&is_correct&limit=100&offset=0`.

행에는 attempt UUID, 사용자/문제 ID, 정오답, score, duration, 생성 시각 등 모델 데이터를 표시한다. 정수 attempt ID로 바꾸지 않는다. 삭제는 `/admin/exercise-attempts/{UUID}` DELETE 후 행 제거. 현재 서버의 attempt_type 계약과의 차이는 19번 문서에서 별도 결정한다.

## FR-QUE-01. 학습 큐 검색·표시

User ID·Batch ID·Exercise ID, 소비 여부 전체/소비/미소비 필터. `GET /admin/exercise-queues?user_id&batch_id&exercise_id&consumed&limit=100&offset=0`. 전체는 consumed 생략, 그 외 true/false.

행은 queue ID, 사용자·문제·batch ID, batch Unit, position, 완료 여부, 생성/소비 등 시각을 표시한다. 소비 상태 변경·큐 재배치 UI는 현재 범위에 없다. 삭제는 해당 정수 ID DELETE 후 행 제거다.

## FR-STA-01. 단어 상태 검색·표시

User ID·Vocabulary ID 선택 검색. 화면 내부의 UserLessonTargetState 이름과 달리 API는 `/admin/user-vocabulary-states?user_id&vocabulary_id&limit=100&offset=0`다. lesson_target_id로 바꾸지 않는다.

행은 상태 ID, 사용자·Vocabulary ID, attempts·correct·wrong_streak, last_attempt_at·last_correct_at·next_review_at·updated_at 등 모델 상태를 표시한다. 삭제는 `/admin/user-vocabulary-states/{id}` DELETE. 관리 화면에서 학습 회수·정오답을 임의 갱신하는 UI는 없다.

## FR-REC-01. 공통 페이지·삭제·예외

검색은 offset=0에서 교체하고 마지막 행 접근 시 다음 100건을 붙인다. 한 페이지가 100건보다 작으면 종료. 조회 중 중복 요청 금지. 날짜 없음은 대체 표기. 삭제 실패 시 행 유지·오류, 성공 시 해당 ID만 제거한다. 스와이프 삭제 등 현재 즉시 삭제 동작과 별도 확인창이 있는 다른 화면을 구분한다.

## AC-REC

1. ID 공백은 전체, ID 0·문자는 검증 실패다.
2. 정답/소비 전체 필터는 false가 아니라 query 생략이다.
3. 101건은 100+1로 누적하고 재검색 시 이전 결과를 섞지 않는다.
4. attempt UUID 삭제와 state 정수 ID 삭제의 경로 타입을 구분한다.
5. 추가 서버 필드가 있다고 기존 표시 필드를 임의 삭제하지 않는다.

근거: `LessonClient/UI/ExerciseAttempt/List/`, `LessonClient/UI/ExerciseQueue/List/`, `LessonClient/UI/UserLessonTargetState/List/`, 대응 DataSource 및 Models.
