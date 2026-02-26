# Release Regression Report

- 실행 일시: 2026-02-26
- 실행자: Codex
- 대상 커밋: `a6045fa` (cycle 시작 시점)

## 1. 빌드 체크 결과

### 1.1 iOS build
- 명령:
  - `xcodebuild -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- 결과: `FAIL`
- 근거:
  - `Unable to open base configuration reference file '/tmp/dogArea-cycle28/OpenAIConfiguration.xcconfig'`

### 1.2 watchOS build
- 명령:
  - `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build`
- 결과: `FAIL`
- 근거:
  - 동일하게 `OpenAIConfiguration.xcconfig` 부재로 build fail

## 2. 핵심 시나리오 점검 결과

### 2.1 로그인/산책/저장/목록
- 결과: `BLOCKED (수동 디바이스 QA 미실행)`
- 근거:
  - CLI 환경에서 UI 수동 시나리오(Apple 로그인, 지도 상호작용, 저장 후 화면 검증) 직접 수행 불가

### 2.2 보완 근거 (자동 스크립트)
- `swift scripts/heatmap_unit_check.swift` -> PASS
- `swift scripts/watch_reliability_unit_check.swift` -> PASS
- `swift scripts/caricature_pipeline_unit_check.swift` -> PASS
- `swift scripts/nearby_hotspot_unit_check.swift` -> PASS
- `swift scripts/feature_flag_rollout_unit_check.swift` -> PASS
- `swift scripts/viewmodel_modernization_unit_check.swift` -> PASS
- `swift scripts/coredata_contract_unit_check.swift` -> PASS
- `swift scripts/swift_stability_unit_check.swift` -> PASS

## 3. 마이그레이션 검증 결과

### 3.1 migration list
- 명령: `npx --yes supabase migration list`
- 결과: `BLOCKED`
- 근거:
  - `Cannot find project ref. Have you run supabase link?`

### 3.2 SQL 변경 점검
- 결과: `PASS`
- 근거:
  - migration 파일 존재 확인:
    - `supabase/migrations/20260226093000_caricature_async_pipeline.sql`
    - `supabase/migrations/20260226095500_nearby_hotspots.sql`
    - `supabase/migrations/20260226103000_feature_flags_and_metrics.sql`

## 4. 종합 판단
- 릴리즈 가능 여부: `NO-GO`
- 선행 조치:
  1. `OpenAIConfiguration.xcconfig`를 CI/로컬 빌드 환경에 주입
  2. Supabase 프로젝트를 `supabase link`로 연결
  3. 실기기/시뮬레이터에서 로그인/산책/저장/목록 수동 QA 수행
