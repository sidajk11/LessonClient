# Swift / Flutter 기능 비교 테스트

결과: **불일치**. 공유 비교 항목 19개 중 일치 9개, 불일치 10개.

테스트의 통과는 실행·관찰 코드가 정상이라는 뜻이며, 앱 간 동등성은 아래 비교 결과로 별도 판정합니다.

## 검증 범위

- Swift: 실제 Models/DataSource/APIClient/문자열 확장/SenseBulkParser를 Swift Package 테스트 타깃에서 컴파일합니다. 앱 실행이나 대체 구현을 사용하지 않습니다.
- Flutter: 기존 위젯·서비스 테스트와 공유 fixture 테스트를 실행합니다. 시도 기록 필터와 레슨 삽입 요청은 실제 화면을 눌러 수집합니다.
- Swift 조회 테스트는 13개 관리 경로의 응답 디코딩·요청 메서드·경로를 검사합니다. 추가로 예문 연결/해제와 문장 삭제를 모의 응답으로 검사합니다.
- 공유 요청 비교에는 메서드·경로·쿼리와 삽입/연결 JSON 본문을 포함합니다. 서버 기본값 vocabulary_ids=[]는 생략과 동등하게 정규화합니다.
- Swift는 URLProtocol, Flutter는 MockClient가 모든 테스트 요청을 가로챕니다. 실제 서버·AI·Google TTS 호출과 서버 데이터 변경은 없습니다.
- 화면 17개 전체의 Swift UI 동작, 실제 음성 출력·저장 대화상자·AI 생성 품질까지 동등하다고 보장하는 테스트는 아닙니다.

## 발견한 차이

### attempt.current_response — 기능 오류 · Swift

현재 서버는 attempt_type을 반환하나 Swift 모델은 is_correct를 필수로 디코딩합니다.

Swift:
```json
"decode_error"
```

Flutter:
```json
"correct"
```

### lesson.korean_topic — 기능 오류 · Flutter

Lesson 번역은 topic 필드지만 Flutter 공통 번역 함수는 text만 읽습니다.

Swift:
```json
"동물"
```

Flutter:
```json
""
```

### login.decoded_fields — 기능 오류 · Swift

폼 인코딩에서 +, &, =를 보존하지 않아 특수문자 계정/비밀번호가 서버에 다른 값으로 전달됩니다.

Swift:
```json
{
  "b": "c",
  "grant_type": "password",
  "password": "p a",
  "scope": "",
  "username": "test tag@example.com"
}
```

Flutter:
```json
{
  "grant_type": "password",
  "password": "p+a&b=c",
  "scope": "",
  "username": "test+tag@example.com"
}
```

### option.language_priority — 표시 정책 차이

Swift는 먼저 온 번역, Flutter는 en-US 번역을 우선 표시합니다.

Swift:
```json
"고양이"
```

Flutter:
```json
"cat"
```

### option.raw_display — 호환성 차이 · Flutter

Flutter는 최상위 display_text/text를 사용하지 않고 translations만 읽습니다.

Swift:
```json
"visible"
```

Flutter:
```json
"translated"
```

### parser.sense_empty_pos — 입력 검증 차이

빈 pos를 Swift는 거부하고 Flutter는 허용합니다.

Swift:
```json
"rejected"
```

Flutter:
```json
"accepted"
```

### parser.sense_without_example — 입력 허용 차이

example 생략을 Swift는 허용하고 Flutter는 거부합니다.

Swift:
```json
"accepted"
```

Flutter:
```json
"rejected"
```

### request.attempt_filter — API 차이 · Swift

Swift는 is_correct=true, Flutter는 현재 서버가 지원하는 attempt_type=correct를 전송합니다.

Swift:
```json
{
  "method": "GET",
  "path": "/admin/exercise-attempts",
  "query": {
    "is_correct": "true",
    "limit": "100",
    "offset": "0",
    "user_id": "1"
  }
}
```

Flutter:
```json
{
  "method": "GET",
  "path": "/admin/exercise-attempts",
  "query": {
    "attempt_type": "correct",
    "limit": "100",
    "offset": "0",
    "user_id": "1"
  }
}
```

### tokens.currency — 표시 차이

통화 기호와 숫자의 공백 규칙이 다릅니다.

Swift:
```json
"I paid$5."
```

Flutter:
```json
"I paid $ 5."
```

### tokens.parentheses — 표시 차이

괄호 안 공백 규칙이 다릅니다.

Swift:
```json
"I ( love ) cats."
```

Flutter:
```json
"I (love) cats."
```

## 일치한 항목

- `exercise.prompt`
- `exercise.type`
- `lesson.unit`
- `parser.sense_valid`
- `request.example_attach`
- `request.lesson_insert`
- `sentence.text`
- `tokens.contractions`
- `vocabulary.korean`

## 재실행

LessonClient 디렉터리에서:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
cd ../admin_flutter
flutter test
cd ../LessonClient
python3 parity/compare.py
```

비교 스크립트는 불일치가 있으면 종료 코드 1을 반환합니다. 로그인 사례의 계정·비밀번호는 fixture의 가짜 문자열이며 실제 계정 정보가 아닙니다.

이번 작업에서는 테스트 구성·fixture·보고서만 추가했으며 발견된 앱 동작은 수정하지 않았습니다.
