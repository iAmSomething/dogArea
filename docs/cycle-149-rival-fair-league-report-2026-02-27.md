# Cycle 149 Report — Rival Fair League Matching (2026-02-27)

## 1. 대상
- Issue: `#149 [P1][Task] 라이벌 공정 매칭 리그(14일 활동량 밴드)`
- Branch: `codex/cycle-149-rival-league`

## 2. 구현 요약
- Supabase 리그 매칭 스키마 추가:
  - `rival_league_policies`
  - `rival_league_assignments`
  - `rival_league_history`
- `rpc_refresh_rival_leagues` 구현:
  - 최근 14일 활동량 기반 리그 산정
  - onboarding 보호/주간 재산정/표본 부족 fallback(`effective_league`) 반영
  - 리그 변화 이력(`rival_league_history`) 기록
- `rpc_get_my_rival_league` 구현:
  - 본인 리그/병합 여부/안내 메시지 조회
- Edge Function `rival-league` 추가:
  - 앱에서 `get_my_league` 액션으로 리그 조회 가능
- 분포 모니터링 뷰 `view_rival_league_distribution_current` 추가

## 3. 변경 파일
- `supabase/migrations/20260227212000_rival_fair_league_matching.sql`
- `supabase/functions/rival-league/index.ts`
- `docs/rival-fair-league-v1.md`
- `docs/release-regression-checklist-v1.md`
- `docs/supabase-schema-v1.md`
- `docs/supabase-migration.md`
- `docs/cycle-149-rival-fair-league-report-2026-02-27.md`
- `README.md`
- `scripts/rival_league_matching_unit_check.swift`
- `scripts/release_regression_checklist_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 유닛 체크
- `swift scripts/rival_league_matching_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- `rpc_refresh_rival_leagues`는 운영 배치(예: 주 1회 cron) 연결이 필요하며, 현재는 수동/운영 경로에서 호출하는 구조.
- 라이벌 UI(Stage 3)에서 `guidance_message`, `fallback_applied` 노출 및 리그 이동 히스토리 화면 연결이 후속으로 필요.
