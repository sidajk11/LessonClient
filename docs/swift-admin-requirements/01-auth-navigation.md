# 01. 인증·메뉴

## FR-AUTH-01. 로그인

입력: 이메일로 표시되는 계정 문자열, 마스킹 비밀번호. 로그인 버튼으로 `POST /app/v1/auth/login`, form-urlencoded `{username:계정,password,grant_type:"password",scope:""}`를 보낸다. 토큰 저장 후 `GET /admin/users/me`로 사용자 정보를 취득하고 관리자 화면으로 전환한다. 실패하면 로그인 화면에 오류를 표시한다. 계정이 실제 이메일 형식이어야 한다는 추가 클라이언트 검증은 현재 없다.

## FR-AUTH-02. 회원가입

“회원가입”으로 같은 폼의 가입 모드로 전환한다. “가입하기”는 `POST /app/v1/auth/join` JSON `{email,password}` 성공 후 별도 입력 없이 로그인 → 사용자 조회 순서로 진행한다. “로그인으로”는 폼을 로그인 모드로 돌린다. 비밀번호 재확인·비밀번호 재설정·사용자 관리 화면은 현재 범위에 없다.

## FR-AUTH-03. 세션·로그아웃

저장된 토큰으로 사용자 복구를 시도한다. 인증된 사용자 상태를 기준으로 로그인/관리 화면을 분기한다. 로그아웃은 사용자 상태와 저장 토큰을 비워 로그인 화면으로 돌아간다. 자동 refresh-token 재발급은 현재 확인되는 기능이 아니다.

## FR-NAV-01. 관리자 메뉴

기본 선택은 레슨이다. 가로 스크롤 가능한 메뉴 버튼과 선택 화면을 연동한다. 순서는 README의 17개 메뉴 그대로다. 하위 화면은 뒤로 가기로 복귀할 수 있다. 메인 진입 시 Phrase 목록을 미리 적재하여 구문 검색·토큰 병합에서 사용한다. 상단 로그아웃을 제공한다. `포럼`은 Form 목록으로 이동한다.

## AC-AUTH

1. 가입 성공 후 자동 로그인되어 사용자 정보와 관리자 화면이 열린다.
2. `a+b&c=d`가 들어간 계정·암호가 form 인코딩에서 손상되지 않아야 한다(기존 Swift 인코딩 결함은 19번 문서 참조).
3. 로그인 실패 시 메인 화면을 표시하지 않으며 입력을 재시도할 수 있다.
4. 로그아웃 후 이전 Bearer 토큰을 다음 사용자 요청에 재사용하지 않는다.
5. 17개 메뉴와 Batches의 문장 유닛 검사가 각각 정확한 화면으로 이동한다.

근거: `LessonClient/UI/Auth/LoginView.swift`, `LessonClient/App/AppState.swift`, `LessonClient/App/MainTabView.swift`, `LessonClient/DataSource/UserDataSource.swift`.
