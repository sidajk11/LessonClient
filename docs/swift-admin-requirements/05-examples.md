# 05. 예문(Example)

## FR-EXA-01. 검색·표시

예문 검색어·Level·Unit을 조합한다. 숫자 필드는 숫자만 유지한다. `GET /admin/examples/search?q&level&unit&limit=400`. 현재 화면의 fetchPage라는 함수명과 달리 offset 페이지 API는 아니다. 응답은 Unit 오름차순(null 마지막), 같은 Unit은 Example ID 순으로 표시한다. 한 부모의 여러 문장을 orderedExampleSentences 순서로 보여준다. 문장 선택은 해당 ExampleSentence 상세로 이동한다.

부모 Unit, 문장 번역, 토큰의 Sense code·CEFR, 학습 단어 연결 상태, 문장에 필요한 최고 Unit을 부가 조회하여 표시한다. 검색 중 이전 요청의 후속 상태 결과가 새 목록을 덮지 않도록 검색 세대 번호를 사용한다. 이 검색은 예문 문장 검색과 다른 API이며 null Vocabulary 예문 포함 여부는 서버 검색 정책에 좌우된다.

## FR-EXA-02. 상태 필터

- “미학습단어 포함만”: Vocabulary로 해석 불가능한 토큰이 있거나 토큰 내장 vocabulary가 없는 항목을 표시한다. 최고 Unit이 원래 Unit보다 큰지와는 별개의 조건이다. 화면의 최고값은 현재 내장 token.vocabulary.unit 중 최댓값을 사용하므로 별도 문장 유닛 검사처럼 모든 후보를 새 조회하지 않는다.
- “tokens 수정필요만”: 문장의 비문장부호 토큰이 하나 이상 있어야 하며 모두 sense_id 또는 phrase_id가 있어야 준비 완료다. 토큰 없음 또는 미연결 토큰이 있으면 수정 필요다.
- 단순 공백 분리 단어 수로 위 조건을 대체하지 않는다. 정확한 해석 순서는 `ExampleTokenVocabularyStatusLoader`와 reference의 SentenceVocabularyAnalysisUseCase를 따른다.

## FR-EXA-03. start_end_index 검사

각 대상 문장의 token_index 순 surface로 문장 전체를 덮을 수 있는지 검사한다. 토큰 없음, start/end null, surface와 원문 불일치를 감지한다. 이 검사는 읽기 전용이다. 현재 구현은 기존 숫자 범위의 오차 자체보다 “누락 또는 재계산 불가능”을 검사한다는 한계가 있다.

## FR-EXA-04. start_end_index 복구

복구 대상 문장별로 범위 재계산이 가능하면 기존 token ID를 유지하고 start_index/end_index만 수정한다. 토큰 없음·surface 불일치로 재계산이 불가능하면 재생성 경로를 사용한다. 각 문장 진행·성공·실패 결과와 복사 가능한 오류 요약을 표시한다. UTF-16 기준 범위와 공백 검증은 07번 문서에 따른다. 검사와 복구를 한 버튼으로 합치지 않는다.

## FR-EXA-05. 전체 생성·토큰 삭제·Sense 추가

“전체 생성”은 현재 대상 예문들의 문장 토큰을 재생성하는 기능이다. 예문 원문을 새로 만드는 기능이 아니다. 문장 단위로 처리하고 상태를 다시 계산한다.

“토큰 삭제”는 해석할 수 없는 학습 단어가 있는 대상으로 선별된 문장의 기존 토큰을 삭제한다. 전체 DB 토큰을 삭제하는 기능이 아니다. “sense 추가”는 누락 Sense 대상 문장을 모아 토큰/후보 정보를 만들고 AI 결과를 파싱하여 word_id·sense_id를 반영한다. 실패 표면형은 모아 복사할 수 있는 결과로 제공한다. 세 동작 모두 중복 실행을 막고 단계별 건수·대상·실패를 보여준다. 정확한 대상 선별·AI 연계는 reference의 ExamplesSearchViewModel 원문을 따른다.

## FR-EXA-06. 예문 실제 삭제

행의 삭제 버튼 → 삭제 확인 → `DELETE /admin/examples/{exampleId}`. 취소하면 요청하지 않는다. 진행 중 같은 행 삭제를 막는다. 성공 시 부모 행과 해당 상태 캐시를 제거하고 실패 시 행을 남긴다. 이 동작은 연결 해제가 아니라 부모 Example 삭제이며 하위 문장·토큰·문제 영향은 서버 cascade 계약에 따른다. 현재 UI 확인문구가 의미하는 삭제 범위를 서버 검증 없이 추가 보장하지 않는다.

## AC-EXA

1. 한 예문에 문장 두 개가 있으면 둘 다 표시하고 서로 다른 상세로 연다.
2. 검사만 실행하면 POST·PUT·DELETE가 발생하지 않는다.
3. 범위 복구 가능 문장은 token ID를 바꾸지 않는다. 실패 문장은 정상이라고 표시하지 않는다.
4. 예문 삭제 취소는 요청 0회, 확인은 부모 ID DELETE 1회다.
5. U3·null·U1 응답은 U1·U3·null 순서다.

근거: `LessonClient/UI/Example/Search/` 전체, `LessonClient/Domain/UseCase/ExampleSentence/`.
