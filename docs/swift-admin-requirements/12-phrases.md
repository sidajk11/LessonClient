# 12. 구문(Phrase)

## FR-PHR-01. 검색·목록

검색어 q를 trim하고 빈 값은 전체. `PhraseDataSource.listPhrases(q,limit:50,offset:0)`으로 최대 50건을 표시한다. 전체 Phrase 캐시가 있으면 캐시 검색을 우선하므로 매번 서버 GET이 발생한다고 가정하지 않는다. 목록에서 text·번역·식별 정보와 상세 진입, 신규 생성·행 삭제를 제공한다. 현재 화면은 무한 페이지 목록이 아니다.

## FR-PHR-02. 여러 구문 생성

```text
phrase: in front of
ko: ~의 앞에
es: delante de

phrase: a lot of
ko: 많은
```

CRLF/CR을 LF로 정규화하고 빈 줄로 블록을 나눈다. `phrase:`(대소문자 무시)가 있는 블록만 처리하고 비어 있으면 제외한다. 나머지 첫 콜론 전 key는 번역 언어, value는 번역이다. 콜론 없는 줄과 빈 value는 무시한다. 블록별 `POST /admin/phrases {text,translations:[{lang,text}]}`. 번역이 없으면 translations 생략. 한 블록 실패 후 다음을 계속한다. 전부 실패하면 전체 오류, 일부 성공이면 생성 결과와 부분 실패 메시지를 함께 반환한다.

## FR-PHR-03. 상세·수정·삭제

text·다국어 번역을 편집하고 normalized·생성 시각 등 메타데이터를 표시한다. text는 trim 후 필수. 번역은 언어별 콜론 줄 형식. `PUT /admin/phrases/{id}` 후 응답 반영. 현재 빈 번역 입력은 nil로 전달하여 변경 생략이 될 수 있으므로 “모든 번역 삭제”로 단정하지 않는다. 상세 삭제는 확인 후 DELETE, 목록의 행 삭제는 현재 별도 확인 없이 실행하는 경로도 있다. 성공 후 목록/캐시에서 제거한다.

## FR-PHR-04. 캐시와 토큰화

메인 화면 진입 시 pageSize=200으로 전체 Phrase를 읽어 캐시한다. 생성·수정·삭제는 캐시에 upsert/remove한다. 토큰 구문 병합이 이 캐시를 사용한다. 생성 직후의 구문이 다음 문장 토큰화에 반영되도록 한다. 캐시의 필터 범위와 정렬은 reference의 PhraseDataSource 원문을 따른다.

## AC-PHR

구문 없는 블록은 저장하지 않는다. 두 블록 중 하나 서버 오류면 성공 구문과 실패 설명을 모두 남긴다. 번역 본문 속 콜론은 보존한다. 삭제한 구문이 캐시 검색에 계속 보이지 않는다.

근거: `LessonClient/UI/Phrase/`, `LessonClient/DataSource/PhraseDataSource.swift`.
