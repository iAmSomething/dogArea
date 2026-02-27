# Cycle 154 Report — Battery Termination Recovery Estimation (2026-02-27)

## 1. 대상
- Issue: `#154 [P0][Task] 배터리 종료 후 미종료 세션 복구 추정 플로우`
- Branch: `codex/cycle-154-battery-recovery`

## 2. 변경 요약
- 앱 재실행 복구 draft 세션에서 자동 확정/자동 재개 분기를 제거
- `추정 종료`(lastMovement+15분) 수동 확정 플로우 추가
- 확정 실패 시 draft 보존(재시도 가능)으로 무결성 보강
- 복구 배너에 추정 근거 문구 노출
- 복구 관련 메트릭(탐지/확정/실패/폐기) 수집 추가
- recoverable 세션 배너를 동일 P0 내 최우선으로 정렬

## 3. 변경 파일
- `dogArea/Views/MapView/MapViewModel.swift`
- `dogArea/Views/MapView/MapView.swift`
- `dogArea/Source/UserdefaultSetting.swift`
- `dogArea/Views/WalkListView/WalkListDetailView.swift`
- `docs/walk-session-recovery-auto-end-v1.md`
- `docs/battery-recovery-estimation-v1.md`
- `docs/release-regression-checklist-v1.md`
- `scripts/walk_session_recovery_auto_end_unit_check.swift`
- `scripts/battery_recovery_estimation_unit_check.swift`

## 4. 유닛 체크
- `swift scripts/battery_recovery_estimation_unit_check.swift` -> PASS
- `swift scripts/walk_session_recovery_auto_end_unit_check.swift` -> PASS
- `swift scripts/walk_runtime_guardrails_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS

## 5. 리스크/후속
- 추정 종료 시각은 이동 분포를 균등 가정하므로, point-level timestamp 기반 정밀 종료 추정은 후속 과제.
- 향후 watch 배터리 종료 시나리오를 별도 시뮬레이터/실기기 QA로 확대 필요.
