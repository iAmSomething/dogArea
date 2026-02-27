# Battery Termination Recovery Estimation v1 (Issue #154)

## 1. 목표
- 배터리 종료/강제 종료 후 앱 재실행 시 draft 세션을 복구한다.
- 복구 draft는 자동 확정하지 않고 사용자 수동 확정만 허용한다.

## 2. 복구 정책
- 진입 조건: `walk.activeSession.v1` 존재 + 12시간 이내 + (elapsedTime > 0 또는 points 존재)
- 우선순위: 앱 첫 진입 시 상단 P0 배너 노출
- 자동 동작 금지
  - 자동 재개 금지
  - 자동 종료/자동 확정 금지

## 3. 종료 추정치
- 기준: `lastMovementAt + inactivityFinalizeInterval(15분)`
- 공식: `estimatedEndAt = min(now, lastMovementAt + 15분)`
- 보정: `estimatedEndAt >= startedAt` 보장
- 최근 이동(`gap < 5분`)이면 추정 종료 대신 복구 권장 문구 노출

## 4. 사용자 액션
- `복구`: 세션을 이어서 재개
- `추정 종료`: 제안 시각으로 수동 확정 저장 (`reason=recovery_estimated`)
- `지금 종료`: 현재 시각으로 수동 확정 저장 (`reason=manual`)
- `닫기`: 배너만 닫고 draft 유지

## 5. 무결성/실패 처리
- 확정 전 원본 draft 보존
- 저장 실패 시 draft를 유지하고 재시도 가능
- 포인트 부족(<3) 시 확정 불가 처리 + 안내 메시지

## 6. 관측 지표
- `recovery_draft_detected`
- `recovery_finalize_confirmed`
- `recovery_finalize_failed`
- `recovery_draft_discarded`
