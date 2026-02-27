# Cycle 152 Report — Indoor Weather Replacement Mission (2026-02-27)

## 1. 대상
- Issue: `#152 [P0][Task] 악천후 실내 대체 미션 정교화`
- Branch: `codex/cycle-152-indoor-weather`

## 2. 구현 요약
- 홈 도메인에 `IndoorMissionStore`/`IndoorMissionBoard`를 추가해 악천후 단계별 실내 미션 치환 엔진 도입
- 실내 미션 카탈로그를 `recordCleanup/petCareCheck/trainingCheck`로 확장
- 미션별 최소 행동량(`minimumActionCount`) 강제 및 미달 시 완료 거절
- 최근 2일 노출 미션을 우선 제외해 반복 노출 제한
- 위험도 단계(`caution/bad/severe`)에 따라 미션 수량/보상 감액 계수 적용
- 홈 UI에 실내 미션 카드 + 진행률 + 행동량 + 완료확인 플로우 반영
- 완료/거절/치환 이벤트 메트릭 추가

## 3. 변경 파일
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/HomeView/HomeView.swift`
- `dogArea/Source/UserdefaultSetting.swift`
- `docs/indoor-weather-mission-v1.md`
- `docs/release-regression-checklist-v1.md`
- `scripts/indoor_weather_mission_unit_check.swift`

## 4. 유닛 체크
- `swift scripts/indoor_weather_mission_unit_check.swift` -> PASS
- `swift scripts/home_goal_tracker_ui_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS

## 5. 리스크/후속
- 실제 기상 API 미연결 환경에서는 `WEATHER_RISK_LEVEL`/`weather.risk.level.v1` 입력값 기반으로 동작하며, 값이 없으면 `caution` fallback 적용.
- Stage 2/3 weather provider 연동 시 risk source를 서버/SDK 결과로 교체 필요.
