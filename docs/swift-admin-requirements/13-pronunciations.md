# 13. 발음법(Pronunciation)

## FR-PRN-01. 목록 검색·페이지·삭제

Word ID·Sense ID·Dialect(전체/US/UK/AU)로 `GET /admin/pronunciations?word_id&sense_id&dialect&limit=50&offset=0`. ID는 선택 정수이며 현재 이 화면은 양수 추가 guard가 없다. 행은 IPA·Word/Sense ID·방언·대표 여부·메타데이터를 표시한다. 다음 페이지 조회, 신규 일괄 입력 이동, 행 DELETE를 제공한다. 일반 수정 폼이 완성되어 있다고 가정하지 않는다.

## FR-PRN-02. 입력 파싱

```text
word: record
pos: noun
ipa: /ˈrɛkərd/

pos: verb
ipa: /rɪˈkɔrd/
```

라인 스트림으로 word·pos를 보관하다 ipa를 만나면 한 항목을 확정한다. ipa 후 pos는 초기화하고 word는 다음 word 줄까지 유지한다. 따라서 두 번째 발음은 word 생략 가능하다. 파싱 목록에 단어·품사·IPA·해석된 Word/Sense ID·상태를 보여준다. 파싱 결과가 없으면 오류다.

## FR-PRN-03. Word 조회·Sense 대응

중복 제거한 단어들을 소문자 lemma로 병렬 조회한다. 하나라도 조회 오류면 이 단계는 실패하며 성공인 척 다음 생성으로 넘어가지 않는다. 해석된 Word ID를 모든 동일 단어 항목에 적용한다. 같은 word의 첫 발음은 sense_id=null. 두 번째부터는 입력 pos와 대소문자 무시 일치하는 첫 Sense를 연결한다. 일치 Sense가 없으면 null로 둔다. 첫 발음에도 무조건 첫 Sense를 넣는 방식으로 바꾸지 않는다.

## FR-PRN-04. 일괄 생성

모든 항목의 Word 해석이 완료되어야 생성할 수 있다. 항목 순서대로 `POST /admin/pronunciations {word_id,sense_id?,ipa,dialect:"US",is_primary:…}`. 현재 생성은 US 고정이며 같은 Word 첫 항목만 대표 true다. 뒤 항목은 false. 중간 요청 실패 시 중단하고 앞선 성공은 유지된다. 파싱/조회/생성 진행 상태와 건수를 구분한다.

## AC-PRN

record 예시에서 2개 항목이 생기고 첫 항목은 Sense 미연결·대표, 두 번째는 verb Sense·비대표다. 조회 실패 Word가 있으면 생성 요청이 시작되지 않는다. UK 필터는 목록 검색에 적용되지만 신규 일괄 생성의 US 고정값을 바꾸지 않는다.

근거: `LessonClient/UI/Pronounciation/`(원본 폴더 철자), `LessonClient/DataSource/PronunciationDataSource.swift`.
