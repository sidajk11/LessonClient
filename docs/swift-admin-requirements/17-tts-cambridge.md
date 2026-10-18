# 17. TTS·Cambridge

## FR-TTS-01. 음성 합성·재생

TTS는 Text-to-Speech(텍스트를 음성으로 변환) 도구다. 텍스트 입력 기본값은 apple. “Synthesize & Play”로 Google Cloud Text-to-Speech `/v1/text:synthesize`를 호출한다. Bearer access token 및 필요한 프로젝트 설정을 외부에서 공급한다. 입력 text, voice languageCode=en-US, 화면 지정 voice name=en-US-Neural2-H, audioEncoding=MP3. base64 audioContent를 디코딩해 고유 임시 MP3를 만들고 AVAudioPlayer로 재생한다. 중복 합성·오류·현재 상태를 표시한다. 서버의 단어/예문 audio 레코드를 자동 수정하지 않는다.

## FR-TTS-02. 중지·저장

Stop은 현재 재생을 멈춘다. Save MP3는 합성 결과가 있어야 사용할 수 있다. 저장 대화상자에서 경로를 선택하고 임시 음원을 복사한다. 기본 파일명은 입력에서 경로 금지 문자와 개행을 정리한 이름이다. 취소는 저장하지 않는다. 같은 목적지가 있으면 현재 구현의 덮어쓰기 동작을 인지할 수 있어야 한다.

현재 토큰 취득 함수가 빈 문자열을 즉시 반환하므로 실제 합성 성공을 보장하지 못한다. 요구사항은 합성 업무 흐름이며 이 인증 결함을 정상 기능으로 재현하라는 뜻이 아니다. 상세는 19번 문서 참조.

## FR-CAM-01. Cambridge 검색·웹 표시

영어 단어 입력 → Go/Enter → trim 후 URL path 인코딩 → `https://dictionary.cambridge.org/dictionary/english-korean/{word}`를 앱 내부 WKWebView에 연다. 입력이 비면 URL을 비우고 “Enter a word” 초기 안내를 표시한다. 같은 URL이면 불필요한 reload를 피한다. 외부 사전 응답·이용 가능 여부는 관리자 API와 별개다.

## FR-CAM-02. 페이지 추출(내부 처리)

페이지 로드 완료 후 JavaScript로 epp-xref·dxref·CEFR(A1~C2), Sense별 dxref와 번역 class 텍스트들을 수집하여 CambridgeExtract 구조로 디코딩한다. 현재 결과는 로그용이며 Word/Sense로 가져오기·저장 버튼이나 결과 편집 UI는 없다. 웹 구조가 바뀌면 빈 결과일 수 있다. 추출 실패를 관리자 DB 저장 실패라고 처리하지 않는다. 콜백 전달이 실제 외부 화면에 연결된 것으로 가정하지 않는다.

## AC-MISC

1. fixture audioContent를 넣으면 MP3 생성·재생·중지·사용자 지정 저장이 가능하다.
2. TTS 호출 실패/잘못된 base64에서 기존 음원과 새 실패 상태를 구분한다.
3. Cambridge 빈 입력은 검색 URL을 만들지 않는다.
4. Cambridge 검색·추출로 관리자 API POST·PUT·DELETE가 발생하지 않는다.

근거: `LessonClient/UI/TTSView/TTSView.swift`, `LessonClient/AI/GoogleTTSService.swift`, `LessonClient/UI/WebView/WebView.swift`, `LessonClient/UI/WebView/WKWebViewContainer.swift`.
