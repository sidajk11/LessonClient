# 19. 현재 제약·미구현·별도 결정사항

이 문서는 소스에 존재하는 결함을 요구사항으로 잘못 복제하는 일을 막기 위한 구분표다. 이 작업에서 아래 코드를 수정하지 않았다. `관찰`과 `권장 결정`을 분리하며 개선사항은 자동 승인으로 해석하지 않는다.

| ID | 관찰된 현재 상태 | 구현 시 결정/주의 |
|---|---|---|
| GAP-01 | VocabularyBulkImportScreen의 body가 빈 Text다 | “여러 개 추가” 화면은 미구현. 작동하는 “새 단어” 블록 생성과 구분 |
| GAP-02 | FormListView의 Edit가 VM 상태만 바꾸고 FormEditorSheet 표시 바인딩이 없다 | 편집 로직 존재/실제 화면 열림을 구분. 연결 완성은 별도 개선 |
| GAP-03 | SentenceTokenListView는 소스에 있지만 MainTab 항목이 아니다 | 독립 토큰 메뉴는 원래 기능이라고 추가하지 않음 |
| GAP-04 | Vocabulary inline 예문 추가 Section과 일부 편집 메서드가 실제 body/진입에 연결되지 않는다 | 실제 “새 예문 추가”·문장 상세 편집을 우선 재현 |
| GAP-05 | Word kind/POS, Form의 일부 조건은 VM/API에만 있고 화면 입력이 없다 | API 지원 조건과 노출된 검색 조건을 별도로 구현 |
| BUG-01 | Word 상세 Sense 추가에서 `createExample(vocabularyId: word.id)` 호출 | Word ID≠Vocabulary ID. 의도는 Sense 대표 예문 생성이며 임의 Vocabulary 오연결은 복제하지 말 것. 안전한 미연결 생성/실제 Vocabulary 지정 중 계약 결정 필요 |
| BUG-02 | APIClient의 form 인코딩이 .urlQueryAllowed 기반이다 | +·&·= 포함 로그인 입력 손상 가능. 정상 form-urlencoded 인코딩으로 보완 권장 |
| BUG-03 | TTS의 fetchAccessTokenFromGcloud가 바로 빈 문자열 반환 | 실서비스 인증 누락. 외부 자격 증명 설정 없이 합성 가능하다고 검수하지 않음 |
| BUG-04 | Vocabulary.updateVocabulary는 nil 필드가 누락될 수 있는데 Sense/Form 교체에서 nil로 해제를 의도한다 | 실제 해제 요구에는 replaceVocabulary처럼 명시적 null 필요. 일반 저장으로 다른 연결을 초기화하면 안 됨 |
| BUG-05 | Word POS를 빈 값으로 저장해 nil을 보내면 Codable의 키 누락으로 실제 삭제가 안 될 수 있다 | 서버의 null 처리 계약 확인 후 빈 값 동작 결정 |
| BUG-06 | Sense 목록은 Word 페이지를 펼치며 다음 로드는 마지막 Sense 행에서 시작한다 | Sense가 없는 페이지면 후속 페이지 도달 불가 가능. 별도 페이지 진행 전략은 개선사항 |
| BUG-07 | 누락 Word 검색의 try? 및 Sense 생성의 Word 조회 try?가 미존재와 네트워크 실패를 합칠 수 있다 | 404만 미존재로 취급하는 보완 권장. 현재 실패를 정상 후보로 단정하지 않음 |
| BUG-08 | Form 저장의 재파싱이 saved 상태를 초기화할 수 있다 | 재저장 중복 생성 가능. 기존 동일 form+type 처리·서버409 정책 결정 필요 |
| BUG-09 | 상세 토큰 재생성은 위치별 min 개수만 PUT하며 잉여 삭제·추가 없이 기존 Sense를 보존한다 | 표면형·구문 수 변경 시 잔여 토큰/의미 오연결 가능. 완전 재생성과 구분하며 개선은 별도 결정 |
| LIMIT-01 | nextUnit이 limit=1 목록에서 max를 구한다 | 서버가 최대 Unit 레슨을 첫 행으로 주지 않으면 실제 다음 Unit이 아님. 서버 정렬 확인 필요 |
| LIMIT-02 | 예문 검색/문장 검색/Vocabulary 검색의 기본 한도와 페이지가 서로 다르다 | 전체 결과를 다 보여준다는 약속 금지. 페이지 개선은 별도 |
| LIMIT-03 | SenseBulkParser는 블록별 word 불일치 검사를 안 하고 example을 선택으로 허용한다 | 한 head에 다른 Word Sense가 섞이지 않게 입력해야 함. 빈 예문 후속 저장 실패 가능 |
| LIMIT-04 | Sense 생성은 기존 Word에 Sense가 있으면 성공/스킵 안내 없이 return한다 | Word 상세의 단일 Sense 추가와 구분. 스킵 안내 보완 권장 |
| LIMIT-05 | Sense 번역 입력 블록과 Sense 수가 다르면 작은 수까지만 처리한다 | 초과 입력이 무시될 수 있음. 개수 검증은 개선사항 |
| LIMIT-06 | Form 없는 Word 자동 생성이 offset=20,limit=200 snapshot을 사용한다 | 전체 미생성 Word를 빠짐없이 처리한다고 명세하지 않음 |
| LIMIT-07 | 범위 검사에서 이미 채워진 start/end 값이 재계산 값과 다른지를 전부 비교하지 않는다 | 범위 누락/surface 불일치 검출과 숫자 오차 전수 검사를 구분 |
| LIMIT-08 | joinTokens의 공백 규칙이 통상 영어 조판과 다르다 | 예: `I paid$5.`, `I ( love ) cats.`. 필요 시 원문 호환과 조판 개선 중 선택, 단순히 Flutter식으로 교체 금지 |
| LIMIT-09 | 레슨 상세·발음 필터 등 일부 화면의 정수 검증은 다른 화면보다 느슨하다 | 모든 숫자 필드가 자동 양수 검증된다고 가정하지 않음 |
| LIMIT-10 | 일괄 재생성은 실제 삭제 후 신규 생성이며 트랜잭션이 아니다 | 실패 시 복구/ID 보존/동일 참조 자동 복원 보장 없음. 운영 테스트 금지 |
| CONTRACT-01 | Swift Attempt DTO·검색은 is_correct 기반이다 | 앞선 parity 테스트 fixture는 attempt_type 기반 API와 차이를 기록했다. 이번 문서 작업에서는 live 서버 재검증하지 않음. 사용할 서버 버전 확인 후 mapping 결정 |
| CONTRACT-02 | 서버의 조인 검색·cascade·정렬·중복 제약을 앱 소스만으로 확정할 수 없다 | source 주석은 의도이고 서버 실행 검증과 다름. API/fixture 계약으로 확인 |
| SECURITY-01 | AI 클라이언트 소스에 자격 증명 하드코딩이 있다 | 이 문서/부록에는 복제하지 않았다. 외부로 전달 금지, 노출된 키의 교체·안전한 설정 분리 권장 |

## 기준에 없는 기능

사용자/권한 CRUD 관리 화면, 비밀번호 초기화, refresh-token 자동 재발급, Cambridge 결과의 DB 가져오기, TTS 음원의 Vocabulary/문장 자동 연결, 전체 배치 rollback, Flutter와의 완전 동등성은 이 Swift 소스에서 확인된 요구 범위가 아니다. 필요하면 새 요구사항으로 정의한다.

## 완료 판정

요구사항을 구현하는 AI는 각 FR에 대해 구현/미구현/계약 확인 필요를 제출하고, AC fixture 테스트 결과와 위 제약에서 달라진 점을 보고해야 한다. 단순 메뉴 수·빌드 성공만으로 동등 기능 완료라고 판단하지 않는다.
