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
- [ ] 자동 종료 정책 ON 상태에서 무활동 30분 자동 종료/폐기 동작
- [ ] 자동 종료 정책 OFF 상태에서 무활동 자동 종료 미동작
- [ ] 저정확도/점프 GPS 샘플이 면적 계산에서 제외됨
- [ ] 산책 중 권한 강등 시 세션 안전 일시중지 + 복구 배너 노출
- [ ] 워치 중복 액션/재동기화 요청(`syncState`)에서 상태 일관성 유지
- [ ] 백그라운드 복귀 후 경과시간 표시가 wall-clock 기준으로 보정됨
- [ ] 저장 후 지도/목록 데이터 일치

### 4.3 목록/상세
- [ ] 산책 목록 로딩 정상
- [ ] 상세 진입/이미지 저장 동작 정상

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
