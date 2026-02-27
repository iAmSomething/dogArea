# Cycle 146 Report — Season Anti-Farming Rules (2026-02-27)

## 1. 대상
- Issue: `#146 [P0][Task] 시즌 안티 농사 규칙(동일 타일 반복 점수 억제)`
- Branch: `codex/cycle-146-season-anti-farming`

## 2. 구현 요약
- Supabase에 시즌 점수 정책 테이블(`season_scoring_policies`)을 추가하고 운영 파라미터 서버화
- `rpc_score_walk_session_anti_farming` 구현:
  - 동일 타일 30분 내 반복 0점 처리
  - 신규 경로 비율(`novelty_ratio`) 기반 보너스 부여
  - 반복/저이동/저신규 조합에서 `score_blocked=true` 차단
- 포인트 단위 점수 원장(`season_tile_score_events`)과 감사 로그(`season_score_audit_logs`) 추가
- `sync-walk` points stage에서 시즌 점수 요약(`season_score_summary`)을 응답으로 반환
- 운영 문서/릴리즈 체크리스트/검증 스크립트 갱신

## 3. 변경 파일
- `supabase/migrations/20260227195500_season_anti_farming_rules.sql`
- `supabase/functions/sync-walk/index.ts`
- `docs/season-anti-farming-v1.md`
- `docs/supabase-schema-v1.md`
- `docs/supabase-migration.md`
- `docs/release-regression-checklist-v1.md`
- `docs/cycle-146-season-anti-farming-report-2026-02-27.md`
- `README.md`
- `scripts/season_anti_farming_unit_check.swift`
- `scripts/release_regression_checklist_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 유닛 체크
- `swift scripts/season_anti_farming_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 현재 앱 UI는 `season_score_summary.explain.ui_reason` 노출 전이라, 서버 응답 기반 설명 UI 연결은 시즌/퀘스트 UI 단계에서 후속 구현 필요.
- 타일 정밀도(`tile_decimal_precision`)는 기본 3으로 설정되어 운영 중 오탐/미탐 비율을 보고 조정해야 함.
