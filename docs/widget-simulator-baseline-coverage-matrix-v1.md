# Widget Simulator Baseline Coverage Matrix v1

- Issue: #802
- Relates to: #731, #692, #617

## 목적
- widget blocker status runner가 보여주는 simulator baseline이 어떤 `WD-*`, `WL-*` 케이스를 커버하는지 같은 case id 언어로 고정합니다.
- `실기기 증적 미완료`와 `저장소 회귀`를 더 빠르게 분리합니다.

## 원칙
- 이 문서는 `real-device evidence`를 대체하지 않습니다.
- `action-regression`은 simulator UI 회귀 baseline입니다.
- `layout-fast-smoke`는 repo contract baseline입니다.
- 따라서 `WD-*`, `WL-*` 케이스는 아래 기준으로 해석합니다.
  - `covered by simulator baseline`: 저장소에서 같은 route / surface contract를 재현하고 있는 상태
  - `closed by real-device evidence`: 실기기 캡처/영상까지 채워 blocker 종료가 가능한 상태

## Baseline Suite Map

| Suite | Coverage Type | Covered Cases | Canonical Refresh |
| --- | --- | --- | --- |
| `action-regression` | simulator UI regression | `WD-001`, `WD-002`, `WD-003`, `WD-004`, `WD-005`, `WD-006`, `WD-007`, `WD-008` | `bash scripts/run_widget_action_regression_ui_tests.sh 'platform=iOS Simulator,name=iPhone 17'` |
| `layout-fast-smoke` | repo contract / static layout gate | `WL-001`, `WL-002`, `WL-003`, `WL-004`, `WL-005`, `WL-006`, `WL-007`, `WL-008` | `bash scripts/run_pr_fast_smoke_widget_layout_checks.sh` |

## Action Coverage Detail

| Case | Simulator Baseline Source |
| --- | --- |
| `WD-001` | `testFeatureRegression_WidgetRouteOpensRivalTab` |
| `WD-002` | `testFeatureRegression_HotspotWidgetRouteOpensRivalWithMatchingRadiusPreset` |
| `WD-003` | `testFeatureRegression_QuestWidgetRouteOpensQuestMissionBoard` |
| `WD-004` | `testFeatureRegression_QuestWidgetRecoveryRouteOpensQuestMissionBoard` |
| `WD-005` | `testFeatureRegression_TerritoryWidgetRouteOpensGoalDetail` |
| `WD-006` | `testFeatureRegression_WidgetStartRouteConvergesMapWalkingState` |
| `WD-007` | `testFeatureRegression_WidgetEndRouteSurfacesSavedOutcomeCard` |
| `WD-008` | `testFeatureRegression_WidgetStartRouteDefersIntoAuthEntryWhenSessionMissing` |

## Layout Coverage Detail

`layout-fast-smoke`는 아래 공통 contract가 깨지지 않는지 확인합니다.

- `WidgetSurfaceLayoutBudget`
- `WidgetSurfacePage`
- `WalkControlWidget` family split / compact CTA budget
- `TerritoryStatusWidget` metric tile / compact fallback
- `QuestRivalStatusWidget` detail/CTA budget
- `HotspotStatusWidget` badge strip / compact policy footnote

즉 `WL-001...WL-008`에 대응하는 surface contract를 repo 수준에서 먼저 고정하고, 실제 clipping 0건 증명은 실기기 evidence pack이 맡습니다.

## Status Runner Output Contract

`bash scripts/manual_blocker_evidence_status.sh widget`는 최소 아래를 보여줘야 합니다.

- `action-regression` / `layout-fast-smoke` pass/fail
- 각 suite의 `coverage`
- `simulator-coverage-summary`
  - 예: `action 8/8, layout 8/8`

## 완료 해석

- simulator baseline이 `8/8 + 8/8`이어도 `#731`, `#692`는 닫지 않습니다.
- blocker closure에는 여전히 아래 둘이 모두 필요합니다.
  - `WD-001...WD-008`
  - `WL-001...WL-008`
