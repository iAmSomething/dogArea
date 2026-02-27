# Cycle 148 Report — Quest Failure Buffer (2026-02-27)

## 1. 대상
- Issue: `#148 [P1][Task] 퀘스트 실패 완충(자동 연장 슬롯 + 감액 보상)`
- Branch: `codex/cycle-148-quest-failure-buffer`

## 2. 구현 요약
- 홈 실내 미션 엔진에 `자동 연장 슬롯(1개)` 정책을 추가
- 연장 보상 감액(`70%`) 및 연속 자동 연장 제한(2일 연속 불가) 반영
- 연장 소멸/쿨다운 상태를 홈 카드 UI 메시지로 노출
- 연장 미션은 시즌 점수/연속 보상 제외(streakEligible=false) 처리
- 연장 상태 메트릭 이벤트 추가:
  - `indoor_mission_extension_applied`
  - `indoor_mission_extension_consumed`
  - `indoor_mission_extension_expired`
  - `indoor_mission_extension_blocked`

## 3. 변경 파일
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/HomeView/HomeView.swift`
- `dogArea/Source/UserdefaultSetting.swift`
- `docs/quest-failure-buffer-v1.md`
- `docs/indoor-weather-mission-v1.md`
- `docs/release-regression-checklist-v1.md`
- `docs/cycle-148-quest-failure-buffer-report-2026-02-27.md`
- `README.md`
- `scripts/quest_failure_buffer_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 유닛 체크
- `swift scripts/quest_failure_buffer_unit_check.swift` -> PASS
- `swift scripts/indoor_weather_mission_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 현재 연장 슬롯 ledger는 클라이언트(UserDefaults) 저장 기반이므로, 다기기 일관성 보장이 필요하면 Supabase 정책 테이블로 이관 필요.
- 시즌 점수 서버 연동 시 연장 미션 제외 규칙을 RPC 레벨에서도 동일하게 적용하는 후속 작업이 필요.
