# Release Regression Checklist v1

## 1. 목적
고도화 이후 핵심 경로(iOS/watchOS 빌드, 로그인/산책/저장/목록, DB 마이그레이션)의 회귀 여부를 릴리즈 전 표준 절차로 점검한다.

## 2. 사전 준비
- [ ] `OpenAIConfiguration.xcconfig` 존재 및 유효 키 설정
- [ ] `supabase link` 완료(원격 project ref 연결)
- [ ] 네트워크 정상 및 패키지 의존성 resolve 완료

## 3. 빌드 체크
### 3.1 iOS
- 명령: `xcodebuild -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- 기대 결과: `** BUILD SUCCEEDED **`

### 3.2 watchOS
- 명령: `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build`
- 기대 결과: `** BUILD SUCCEEDED **`

## 4. 핵심 시나리오 체크
### 4.1 로그인
- [ ] Apple 로그인 성공
- [ ] 기존 사용자/신규 사용자 분기 정상 동작

### 4.2 산책/기록
- [ ] 산책 시작 -> 포인트 추가 -> 종료 플로우 정상
- [ ] 시작 카운트다운 OFF: 시작 탭 후 즉시 산책 시작
- [ ] 시작 카운트다운 ON: 카운트다운 취소 시 산책 미시작
- [ ] 종료 3액션(저장하고 종료/계속 걷기/기록 폐기) 결과 정상
- [ ] 포인트 자동 기록 ON: 이동 중 자동 포인트 누적 정상
- [ ] 포인트 자동 기록 OFF: 수동 입력에서만 포인트 누적
- [ ] 앱 재실행 시 미종료 세션 복구 배너 노출(복구/폐기)
- [ ] 무이동 5분/12분/15분 단계 정책(휴식 후보/경고/자동 종료) 동작
- [ ] 자동 종료 정책은 고정(v1)이며 설정에서 비활성화되지 않음
- [ ] 저정확도/점프 GPS 샘플이 면적 계산에서 제외됨
- [ ] 산책 중 권한 강등 시 세션 안전 일시중지 + 복구 배너 노출
- [ ] 권한 거부 상태에서 복구 배너 `설정 열기` 버튼으로 시스템 설정 이동 가능
- [ ] 워치 중복 액션/재동기화 요청(`syncState`)에서 상태 일관성 유지
- [ ] 백그라운드 복귀 후 경과시간 표시가 wall-clock 기준으로 보정됨
- [ ] 오프라인 상태 산책 저장 후 동기화 큐 적재 확인
- [ ] 오프라인 상태에서 `오프라인 모드` 배지 노출 + 온라인 복귀 후 자동 동기화 완료 토스트 노출
- [ ] 온라인 복귀 시 큐가 `session -> points -> meta` 순서로 재전송
- [ ] 토큰 만료(401/403) 시 큐 보존 + 재인증 후 재동기화 재개
- [ ] 인증 만료 상태 복구 배너에서 `다시 로그인` 버튼으로 재인증 시트 진입 가능
- [ ] 지도 이미지 미생성 상태에서도 세션/포인트 저장 성공
- [ ] 저장 후 지도/목록 데이터 일치
- [ ] 폴리곤 1000건+ 환경에서 줌아웃 시 전체 오버레이 과밀 없이 클러스터 중심으로 표시
- [ ] LOD 모드에서 단일 클러스터(1:1) 폴리곤만 선택 렌더되고 지도 조작 지연이 완화됨
- [ ] 줌인 상태에서 폴리곤 상세 접근(탭/상세 진입) 가능
- [ ] 산책 시작 전 1탭 pet switcher로 대상 반려견 순환 변경 가능
- [ ] 산책 시작 직전 시간대/요일 기반 자동 제안이 적용되고 변경 로그가 수집됨

### 4.3 목록/상세
- [ ] 산책 목록 로딩 정상
- [ ] 상세 진입/이미지 저장 동작 정상
- [ ] 가입 프로필 이미지 업로드 실패 시 복구 배너(재시도/재로그인) 동작 정상
- [ ] Home/Map/Setting/WalkList 화면 간 선택 반려견 상태가 즉시 동기화됨
- [ ] 홈에서 비활성 Picker가 제거되고 목표 카드(현재/목표/남은 면적)가 표시됨
- [ ] 목표 카드 접근성 라벨(VoiceOver) 읽기 시 핵심 값이 순서대로 전달됨

## 5. 마이그레이션 검증 시나리오
### 5.1 상태 확인
- 명령: `npx --yes supabase migration list`
- 기대 결과: linked 프로젝트 기준 migration state 확인 가능

### 5.2 SQL 변경 검토
- [ ] 신규 migration 파일 존재 확인
- [ ] DDL/RLS/함수 변경사항 문서와 일치

## 6. 결과 기록 템플릿
- 실행 일시:
- 실행자:
- 대상 브랜치/커밋:

### 6.1 빌드
- iOS: `PASS | FAIL | BLOCKED`
- watchOS: `PASS | FAIL | BLOCKED`
- 근거 로그:

### 6.2 핵심 시나리오
- 로그인: `PASS | FAIL | BLOCKED`
- 산책/저장: `PASS | FAIL | BLOCKED`
- 목록/상세: `PASS | FAIL | BLOCKED`
- 근거:

### 6.3 마이그레이션
- migration list: `PASS | FAIL | BLOCKED`
- SQL 검토: `PASS | FAIL | BLOCKED`
- 근거:

### 6.4 종합 판단
- 릴리즈 가능 여부: `GO | NO-GO`
- 잔여 이슈/액션:

## 7. 예외 시나리오 게이트 (P0/P1)
- 참조 매트릭스: `docs/fault-injection-matrix-v1.md`
- 실행 런북: `docs/fault-injection-runbook-v1.md`
- 결과 템플릿: `docs/fault-injection-result-template-v1.md`
- [ ] P0 전 항목 PASS 확인
- [ ] P1 실패 항목은 우회/복구 전략 및 담당자/일정 명시
- [ ] 릴리즈 PR 본문에 매트릭스 링크 + 실행 결과 링크 첨부
- 자동 차단 규칙:
  - `P0 FAIL >= 1` -> `NO-GO`

## 8. 스크린샷 증적 (UI 변경 필수)
- [ ] iPhone SE 홈 스크린샷 첨부 (목표 카드 줄바꿈/겹침 없음)
- [ ] iPhone Pro Max 홈 스크린샷 첨부 (목표 카드 정보 밀도 균형 확인)
