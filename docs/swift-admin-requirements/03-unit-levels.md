# 03. 유닛 레벨

## FR-ULV-01. 검색·페이지

유닛 레벨 메뉴에서 Level·Start Unit 선택 조건으로 검색한다. 입력은 숫자만 유지하고 비면 조건을 생략한다. 입력된 조건은 1 이상 정수여야 한다. `GET /admin/unit-levels?level&start_unit&limit=100&offset=0`. 다음 페이지는 마지막 항목 접근 시 offset을 증가하여 추가한다. 검색·초기화는 기존 페이지와 편집 상태를 초기화한다. 100건 미만 응답이면 더 이상 조회하지 않는다.

## FR-ULV-02. 생성

Level·Start Unit 모두 1 이상 필수. `POST /admin/unit-levels {level,start_unit}` 후 목록 갱신. 중복·구간 충돌 규칙은 서버 오류를 표시하며 클라이언트가 임의로 재번호를 매기지 않는다.

## FR-ULV-03. 행 편집·삭제

기존 행을 편집 상태로 전환하여 Level·Start Unit을 수정한다. 저장은 검증 후 `PUT /admin/unit-levels/{id}`. 취소/되돌리기는 원래 값으로 복구한다. 삭제는 `DELETE /admin/unit-levels/{id}` 성공 후 해당 행 제거. 현재 삭제에 별도 확인이 없는 경우 이를 새로운 확인 흐름이 존재하는 것처럼 설명하지 않는다.

## AC-ULV

빈 조건은 전체, 0은 검증 실패, 101건은 두 페이지로 처리한다. 편집 취소는 요청 없이 원래 값으로 돌아간다. 저장/삭제 실패 시 원래 행을 유지한다.

근거: `LessonClient/UI/UnitLevel/List/`, `LessonClient/DataSource/UnitLevelDataSource.swift`.
