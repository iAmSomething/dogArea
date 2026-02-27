# Cycle 151 Report — Weather Feedback Loop (2026-02-27)

## 1. 대상
- Issue: `#151 [P1][Task] 날씨 오판 보정(체감 날씨 피드백 루프)`
- Branch: `codex/cycle-151-weather-feedback`

## 2. 구현 요약
- 홈 실내 대체 미션 카드에 `체감 날씨 다름` 1탭 액션과 주간 잔여 반영 횟수 UI 추가
- 체감 피드백 로직 구현:
  - 당일 판정만 재평가
  - 주간 2회 제한
  - `severe->bad`, `bad->caution`, `caution` 유지(완전 해제 금지)
- 피드백 반영 결과를 홈 카드/상태 메시지로 즉시 노출
- 메트릭 이벤트 추가:
  - `weather_feedback_submitted`
  - `weather_feedback_rate_limited`
  - `weather_risk_reevaluated`
- Supabase KPI 뷰 `view_weather_feedback_kpis_7d` 추가로 오탐/정탐/제한 비율 관측 경로 제공

## 3. 변경 파일
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/HomeView/HomeView.swift`
- `dogArea/Source/UserdefaultSetting.swift`
- `supabase/migrations/20260227203000_weather_feedback_kpis.sql`
- `docs/weather-feedback-loop-v1.md`
- `docs/indoor-weather-mission-v1.md`
- `docs/release-regression-checklist-v1.md`
- `docs/supabase-schema-v1.md`
- `docs/supabase-migration.md`
- `docs/cycle-151-weather-feedback-loop-report-2026-02-27.md`
- `README.md`
- `scripts/weather_feedback_loop_unit_check.swift`
- `scripts/release_regression_checklist_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 유닛 체크
- `swift scripts/weather_feedback_loop_unit_check.swift` -> PASS
- `swift scripts/indoor_weather_mission_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 현재는 클라이언트 저장 기반 주간 제한이므로, 서버 정책 동기화가 필요하면 후속으로 제한 로직을 서버 검증 경로로 이관해야 함.
- Weather provider 실연동 단계(#133~#135)에서 피드백 가중치와 위험도 재평가 매핑을 서버 정책화하는 작업이 필요.
