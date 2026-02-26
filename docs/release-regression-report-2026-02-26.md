# Release Regression Report (2026-02-26)

- 실행 일시: 2026-02-26
- 실행자: Codex
- 대상 브랜치/커밋: `codex/cycle-63-release-regression` / `a19608a` 기준

## 1. 빌드 체크 결과

### 1.1 iOS build
- 명령:
  - `xcodebuild -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- 결과: `FAIL`
- 근거:
  - SPM resolve 단계에서 remote fetch 실패
  - 핵심 에러: `fatal: Unable to read current working directory: No such file or directory`

### 1.2 watchOS build
- 명령:
  - `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build`
- 결과: `FAIL`
- 근거:
  - SPM 태그 조회 실패
  - 핵심 에러: `fatal: cannot change to .../SourcePackages/repositories/OpenAPIKit-...: No such file or directory`

## 2. 핵심 시나리오 점검 결과

### 2.1 로그인/산책/저장/목록
- 결과: `BLOCKED (수동 디바이스 QA 미실행)`
- 근거:
  - CLI 환경에서 Apple 로그인/지도 상호작용/저장 후 UI 검증을 직접 수행할 수 없음

### 2.2 보완 근거 (자동 검증)
- `swift scripts/release_regression_checklist_unit_check.swift` -> `PASS`
- `swift scripts/fault_injection_matrix_unit_check.swift` -> `PASS`

## 3. 마이그레이션 검증 결과

### 3.1 migration list
- 명령: `npx --yes supabase migration list --linked`
- 결과: `BLOCKED`
- 근거:
  - `Cannot find project ref. Have you run supabase link?`

### 3.2 SQL 변경 점검
- 결과: `PASS`
- 근거:
  - 운영 migration 파일과 체크리스트 문서 계약 일치 확인

## 4. 배포 파이프라인 검증 결과

### 4.1 workflow 정의 상태
- 명령: `gh workflow list --all`
- 결과: `BLOCKED`
- 근거:
  - `fault-injection-gate`는 active 확인
  - Firebase Distribution 전용 workflow는 현재 브랜치에 미정의
  - Apple Developer 계정 만료 상태로 배포 체인 활성화는 보류

### 4.2 최근 실행 상태
- 명령: `gh run list --workflow fault-injection-gate.yml --limit 5`
- 결과: `PASS`
- 근거:
  - 최근 5회 모두 `completed/success`

## 5. P0/P1 예외 게이트 결과
- P0 fail count: `0`
- P1 fail count: `3` (iOS build fail, watchOS build fail, supabase linked migration check blocked)
- P1 대응 계획:
  1. SPM 캐시 정리 후 빌드 재검증 (`DerivedData/SourcePackages` 정리)
  2. `supabase link --project-ref <ref>` 재연결 후 migration list 재실행
  3. 배포용 workflow 정의 및 시크릿 주입은 계정 복구 후 재개

## 6. 배포 전/후 핵심 지표 비교 준비
- 기준 뷰: `public.view_rollout_kpis_24h`
- 상태: `READY (측정 경로 확정, 현재 링크 미연결로 수집 보류)`
- 비교 표:

| KPI | 배포 전 24h | 배포 후 24h | 목표 |
|---|---:|---:|---:|
| walk_save_success_rate | N/A | N/A | >= 0.98 |
| watch_action_loss_rate | N/A | N/A | <= 0.01 |
| caricature_success_rate | N/A | N/A | >= 0.90 |
| nearby_opt_in_ratio | N/A | N/A | 관측 |

## 7. 종합 판단
- 릴리즈 가능 여부: `NO-GO`
- 잔여 액션:
  1. 빌드 환경(SPM cache + xcconfig) 안정화
  2. Supabase 링크 복구 후 DB 검증 재실행
  3. 수동 디바이스 QA(로그인/산책/저장/목록) 실행 로그 첨부
