# 기능별 구현·검수 체크리스트

각 항목의 상세 입력·API·예외·AC는 연결 문서에 있다. 체크는 구현 완료 표시가 아니라 새 구현의 진행 관리용이다. 현재 소스의 미구현/미연결 기능은 해당 문서 및 19-current-limitations를 우선 확인한다.


## [00-common](00-common.md)

- [ ] `FR-COM-01` 통신
- [ ] `FR-COM-02` 작업 상태
- [ ] `FR-COM-03` 다국어·텍스트
- [ ] `FR-COM-04` 보안·운영 보호

## [01-auth-navigation](01-auth-navigation.md)

- [ ] `FR-AUTH-01` 로그인
- [ ] `FR-AUTH-02` 회원가입
- [ ] `FR-AUTH-03` 세션·로그아웃
- [ ] `FR-NAV-01` 관리자 메뉴

## [02-lessons](02-lessons.md)

- [ ] `FR-LES-01` 목록·Unit 검색
- [ ] `FR-LES-02` 새 레슨
- [ ] `FR-LES-03` 레슨 삽입
- [ ] `FR-LES-04` 여러 레슨 생성
- [ ] `FR-LES-05` 상세 편집·삭제
- [ ] `FR-LES-06` 레슨의 단어·문제
- [ ] `FR-LES-07` 복사

## [03-unit-levels](03-unit-levels.md)

- [ ] `FR-ULV-01` 검색·페이지
- [ ] `FR-ULV-02` 생성
- [ ] `FR-ULV-03` 행 편집·삭제

## [04-vocabulary](04-vocabulary.md)

- [ ] `FR-VOC-01` 단어·Level·Unit 검색
- [ ] `FR-VOC-02` 예문 없는 단어 필터
- [ ] `FR-VOC-03` 연결 검사·검사결과 적용
- [ ] `FR-VOC-04` AI 예문 만들기
- [ ] `FR-VOC-05` 신규 생성
- [ ] `FR-VOC-06` 상세 조회·기본 저장·삭제
- [ ] `FR-VOC-07` 레슨·Sense·Form 변경
- [ ] `FR-VOC-08` 예문 신규·편집·연결 해제
- [ ] `FR-VOC-09` 기존 예문 검색·연결

## [05-examples](05-examples.md)

- [ ] `FR-EXA-01` 검색·표시
- [ ] `FR-EXA-02` 상태 필터
- [ ] `FR-EXA-03` start_end_index 검사
- [ ] `FR-EXA-04` start_end_index 복구
- [ ] `FR-EXA-05` 전체 생성·토큰 삭제·Sense 추가
- [ ] `FR-EXA-06` 예문 실제 삭제

## [06-example-sentences](06-example-sentences.md)

- [ ] `FR-SEN-01` 문장 검색
- [ ] `FR-SEN-02` 다중 문장 검색
- [ ] `FR-SEN-03` 문장 삭제
- [ ] `FR-SEN-04` 문장별 문제 삭제·자동 생성
- [ ] `FR-SEN-05` 문장 상세 편집
- [ ] `FR-SEN-06` 블록 문장 추가 하위 화면

## [07-sentence-tokens](07-sentence-tokens.md)

- [ ] `FR-TOK-01` 생성·구문 병합·범위
- [ ] `FR-TOK-02` 재생성·전체 삭제
- [ ] `FR-TOK-03` 표시·복사
- [ ] `FR-TOK-04` Sense 일괄 할당
- [ ] `FR-TOK-05` 번역 일괄 입력
- [ ] `FR-TOK-06` 단건 편집
- [ ] `FR-TOK-07` 소스에 존재하는 토큰 목록

## [08-exercises](08-exercises.md)

- [ ] `FR-EXR-01` 전체 검색·표시
- [ ] `FR-EXR-02` 정답 검사
- [ ] `FR-EXR-03` 문장별 문제 목록
- [ ] `FR-EXR-04` 수동 생성
- [ ] `FR-EXR-05` 누락 문제 자동 생성
- [ ] `FR-EXR-06` 상세 보기 편집·삭제

## [09-learning-records](09-learning-records.md)

- [ ] `FR-ATT-01` 시도 기록 검색·표시
- [ ] `FR-QUE-01` 학습 큐 검색·표시
- [ ] `FR-STA-01` 단어 상태 검색·표시
- [ ] `FR-REC-01` 공통 페이지·삭제·예외

## [10-words](10-words.md)

- [ ] `FR-WRD-01` 검색·목록
- [ ] `FR-WRD-02` 삭제
- [ ] `FR-WRD-03` 상세·POS 편집
- [ ] `FR-WRD-04` Sense 하나 추가
- [ ] `FR-WRD-05` Sense 번역 블록 추가·갱신
- [ ] `FR-WRD-06` Sense 예문 연결
- [ ] `FR-WRD-07` 전체 Sense 삭제·복사

## [11-forms](11-forms.md)

- [ ] `FR-FRM-01` 목록·검색·선택
- [ ] `FR-FRM-02` 삭제·편집 상태
- [ ] `FR-FRM-03` 블록 입력·미리보기·저장
- [ ] `FR-FRM-04` 단어 하나 AI 생성
- [ ] `FR-FRM-05` Form 없는 Word 자동 처리

## [12-phrases](12-phrases.md)

- [ ] `FR-PHR-01` 검색·목록
- [ ] `FR-PHR-02` 여러 구문 생성
- [ ] `FR-PHR-03` 상세·수정·삭제
- [ ] `FR-PHR-04` 캐시와 토큰화

## [13-pronunciations](13-pronunciations.md)

- [ ] `FR-PRN-01` 목록 검색·페이지·삭제
- [ ] `FR-PRN-02` 입력 파싱
- [ ] `FR-PRN-03` Word 조회·Sense 대응
- [ ] `FR-PRN-04` 일괄 생성

## [14-senses](14-senses.md)

- [ ] `FR-SNS-01` 목록·검색·페이지
- [ ] `FR-SNS-02` 블록 파싱·미리보기
- [ ] `FR-SNS-03` 저장
- [ ] `FR-SNS-04` 상세·수정·삭제
- [ ] `FR-SNS-05` 누락 Sense 후보·자동 생성

## [15-batches](15-batches.md)

- [ ] `FR-BAT-01` LemmaTest
- [ ] `FR-BAT-02` SenseGenTest
- [ ] `FR-BAT-03` 예문추가
- [ ] `FR-BAT-04` 예문 없는 단어 재생성
- [ ] `FR-BAT-05` Word 다시 생성
- [ ] `FR-BAT-06` Form 다시 생성
- [ ] `FR-BAT-07` 레슨 삭제
- [ ] `FR-BAT-08` 레슨 추가

## [16-sentence-unit-check](16-sentence-unit-check.md)

- [ ] `FR-UNT-01` 입력·검사 상태
- [ ] `FR-UNT-02` 분석 알고리즘
- [ ] `FR-UNT-03` 결과·오류

## [17-tts-cambridge](17-tts-cambridge.md)

- [ ] `FR-TTS-01` 음성 합성·재생
- [ ] `FR-TTS-02` 중지·저장
- [ ] `FR-CAM-01` Cambridge 검색·웹 표시
- [ ] `FR-CAM-02` 페이지 추출(내부 처리)

