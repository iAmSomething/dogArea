# Epic #123 Closure Evidence Snapshot (2026-03-09, Resolved)

- 대상 에픽: #123 `[Epic] 게임 레이어 1차: 시즌제+퀘스트+라이벌+날씨연동`
- 근거 수집 이슈: #411 `[Epic/QA] #123 종료를 위한 KPI·프라이버시·QA 근거 수집`

## 1. 목적

`#123`의 남은 DoD 3개를 2026-03-09 기준으로 재점검하고, QA/프라이버시/KPI 측면에서 에픽을 닫아도 되는지 최종 판정한다.

## 2. 실행 기준

이번 근거 수집은 이미 머지된 단계 이슈와 운영 문서를 다시 묶어 판정한다.

- Season:
  - #124 Stage1 정책
  - #125 Stage2 파이프라인
  - #126 Stage3 UI
- Quest:
  - #127 Stage1 정책
  - #128 Stage2 엔진
  - #129 Stage3 UX
- Rival:
  - #130 Stage1 프라이버시 정책
  - #131 Stage2 백엔드
  - #132 Stage3 클라이언트 UX
- Weather:
  - #133 Stage1 정책
  - #134 Stage2 엔진
  - #135 Stage3 UX
- 공통 관측/QA:
  - #206 공통 QA/관측 지표
  - #247 KPI 대시보드 뷰

## 3. DoD 판정

| DoD | 상태 | 근거 | 메모 |
| --- | --- | --- | --- |
| 4개 기능이 단계별 DoD를 충족하고 릴리스 리스크가 QA 기준 이내 | `PASS` | `docs/game-layer-observability-qa-v1.md`, `docs/cycle-206-game-layer-observability-qa-report-2026-03-03.md`, `bash scripts/ios_pr_check.sh` PASS | 시즌/퀘스트/라이벌/날씨 관련 정적 체크와 앱 빌드 게이트가 main 기준 통과 |
| 개인정보 보호 기준(격자화/지연반영/최소표본)이 검증됨 | `PASS` | `docs/rival-privacy-policy-stage1-v1.md`, `docs/rival-privacy-hard-guard-v1.md`, `docs/hotspot-widget-privacy-mapping-v1.md`, `swift scripts/rival_privacy_policy_stage1_unit_check.swift`, `swift scripts/rival_privacy_hard_guard_unit_check.swift`, `swift scripts/hotspot_widget_privacy_unit_check.swift` | `k>=20`, 주간 30분/야간 60분 지연, 민감 구역 마스킹, 위젯 privacy mapping까지 연결됨 |
| 주간 리텐션 개선 지표 측정 가능(이벤트/대시보드 확보) | `PASS` | `docs/game-layer-observability-qa-v1.md`, `docs/feature-flag-rollout-monitoring-v1.md`, `supabase/migrations/20260303194000_game_layer_kpi_dashboard_view.sql`, `view_game_layer_kpis_7d`, `view_rollout_kpis_24h` | KPI 이벤트, 7일 집계 뷰, 24시간 rollout KPI 경로가 모두 존재 |

## 4. QA/릴리즈 게이트 근거

### 4.1 공통 QA 기준

`docs/game-layer-observability-qa-v1.md`는 다음을 고정한다.

- 공통 이벤트 규약
- 도메인별 필수 이벤트
- KPI 목표값
- 릴리즈 블로킹 규칙
- 공통 E2E 시나리오

또한 `docs/cycle-206-game-layer-observability-qa-report-2026-03-03.md`는 위 문서가 `#206` 범위로 추가되고 `ios_pr_check`에 연결됐음을 남긴다.

### 4.2 main 기준 검증

이번 사이클에서 다음을 재실행했다.

- `swift scripts/game_layer_observability_qa_unit_check.swift`
- `swift scripts/game_layer_kpi_dashboard_unit_check.swift`
- `swift scripts/rival_privacy_policy_stage1_unit_check.swift`
- `swift scripts/rival_privacy_hard_guard_unit_check.swift`
- `swift scripts/hotspot_widget_privacy_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `bash scripts/ios_pr_check.sh`

판정:

- 문서/정적 체크: PASS
- backend check: PASS
- iOS build + 정적 체크: PASS

즉, `#123`의 QA/릴리즈 근거는 에픽 종료 기준으로 충분하다.

## 5. 개인정보 보호 근거

### 5.1 정책 문서

정책 문서 기준으로 다음 요구가 명시돼 있다.

- 격자 기반 노출
- 최소 표본 `k>=20`
- 주간 30분 / 야간 60분 지연 반영
- 민감 구역 마스킹
- opt-in 전 비노출 / 철회 즉시 중단
- 위젯에서는 좌표/정밀 카운트 미노출

관련 문서:

- `docs/rival-privacy-policy-stage1-v1.md`
- `docs/rival-privacy-hard-guard-v1.md`
- `docs/hotspot-widget-privacy-mapping-v1.md`

### 5.2 구현/게이트 근거

다음 체크가 정책과 구현을 연결한다.

- `swift scripts/rival_privacy_policy_stage1_unit_check.swift`
- `swift scripts/rival_privacy_hard_guard_unit_check.swift`
- `swift scripts/hotspot_widget_privacy_unit_check.swift`

핵심 근거:

- `privacy_guard_policies`
- `privacy_sensitive_geo_masks`
- `privacy_guard_audit_logs`
- `view_privacy_guard_alerts_24h`
- `rpc_get_nearby_hotspots`
- `rpc_get_widget_hotspot_summary`

판정:

- `격자화/지연반영/최소표본` 기준은 문서, migration, widget mapping, audit path까지 모두 연결돼 있다.

## 6. KPI 측정 가능성 근거

### 6.1 이벤트 경로

`docs/game-layer-observability-qa-v1.md` 기준으로 다음 이벤트가 고정돼 있다.

- `season_score_applied`
- `season_decay_applied`
- `season_reward_claimed`
- `quest_progress_applied`
- `quest_reward_claimed`
- `quest_claim_duplicate_blocked`
- `rival_privacy_opt_in_completed`
- `rival_leaderboard_fetched`
- `rival_privacy_guard_blocked`
- `weather_replacement_applied`
- `weather_shield_consumed`
- `weather_feedback_submitted`

### 6.2 대시보드 경로

`#247` 결과로 다음 측정 뷰가 존재한다.

- `public.view_game_layer_kpis_7d`

해당 뷰는 다음 KPI를 노출한다.

- `quest_completion_rate_7d`
- `quest_claim_duplicate_rate_7d`
- `season_participation_rate_7d`
- `rival_opt_in_rate_7d`
- `weather_replacement_acceptance_rate_7d`
- `sync_auth_refresh_failure_rate_24h`

또한 rollout 운영 경로에는 다음 뷰가 존재한다.

- `public.view_rollout_kpis_24h`

관련 문서:

- `docs/feature-flag-rollout-monitoring-v1.md`
- `docs/release-regression-checklist-v1.md`

관련 체크:

- `swift scripts/game_layer_kpi_dashboard_unit_check.swift`

판정:

- KPI는 이벤트 정의와 SQL 집계 뷰 기준으로 측정 가능 상태다.

## 7. 결론

2026-03-09 기준 `#123`의 남은 DoD 3개는 모두 충족된다.

- QA/릴리즈 근거: PASS
- 개인정보 보호 근거: PASS
- KPI 측정 가능성 근거: PASS

즉, `#411`은 해결 완료로 닫을 수 있고, `#123`도 에픽 종료가 가능하다.
