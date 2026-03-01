# Cycle 170 Report (Issue #129)

## Issue
- #129 `[Task][Quest][Stage 3] 퀘스트 UX/알림/완료 흐름 구현`

## What changed
1. `HomeView`에 퀘스트 위젯 탭(`일일/주간`) 추가
2. `HomeView`에 퀘스트 리마인드 토글 UI 추가(매일 20:00, 1일 1회)
3. `HomeViewModel`에 로컬 알림 스케줄러(`UNUserNotificationCenter`) 추가
4. 실패/만료/악천후에 대한 대체 행동 제안 문구 계산 로직 추가

## Verification
- `swift scripts/quest_stage3_ux_reminder_unit_check.swift`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` (워크트리 상태에 따라 선택 실행)

## Notes
- 리마인드 토글은 사용자 명시 동작 시 권한 요청을 수행
- 권한 거부 시 토글은 자동 OFF로 복귀
