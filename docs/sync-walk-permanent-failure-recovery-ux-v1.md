# SyncWalk Permanent Failure Recovery UX v1

## Goal
- `schema_mismatch` 계열 영구 실패를 단순 카운트 배너로 남기지 않는다.
- 사용자가 `무슨 상태인지`, `무엇을 할 수 있는지`, `기기 기록은 남는지`를 바로 이해하게 한다.

## Recovery split
- `rebuildable`
  - 현재 로컬 산책 기록 기준으로 outbox stage를 다시 만들 수 있는 경우
  - 예: 예전 형식 payload, 잘못 저장된 시간 범위, 복구된 `pet_id`
- `archiveOnly`
  - 로컬 기록은 유지하되 현재 서버 계약으로는 동기화만 정리해야 하는 경우
  - 예: 반려견 연결 정보가 없는 오래된 기록, 서버에 없는 pet reference
- `supportRequired`
  - 계정/소유권/인증 문맥 확인이 필요한 경우
  - 예: ownership conflict, auth conflict, unknown permanent failure

## User surface
- 지도 상단 배너 title:
  - `동기화 정리가 필요한 기록 n건`
- body:
  - rebuild/cleanup/support 분기를 한 문단에서 요약
- detail lines:
  - 최대 3줄, 이유를 사용자 언어로 설명

## Actions
- `복구 다시 만들기`
  - rebuildable session만 최신 로컬 DTO 기준으로 stage 재생성
  - 성공 시 pending queue로 되돌아가고 permanent count 감소
- `동기화 목록 정리`
  - archiveOnly session만 outbox에서 제거
  - 로컬 기록은 유지
- `문의 메일`
  - supportRequired session id와 사용자 id를 포함한 `mailto:` 생성
- `나중에 보기`
  - 현재 세션에서 banner suppression을 길게 적용

## Banner policy
- permanent failure가 있더라도 dismiss 후 즉시 다시 붙지 않게 suppression window를 기존보다 길게 둔다.
- dismiss는 영구 실패 삭제가 아니라 노출만 미룬다.
- rebuild/archive action이 실제 count를 줄이면 banner는 자연스럽게 약해지거나 사라진다.

## Verification
- UI preview stub로 `3건 = rebuildable 1 + archiveOnly 1 + supportRequired 1` 상태를 재현한다.
- rebuild action 후 `3건 -> 2건` 전환을 UI 회귀 테스트로 검증한다.
- static check로 아래 경로를 고정한다.
  - `SyncOutboxStore.permanentFailureSessions`
  - `SyncOutboxStore.replaceStagesForSessions`
  - `SyncOutboxStore.archivePermanentFailures`
  - `MapViewModel.rebuildRecoverableSyncOutboxSessions`
  - `MapViewModel.archiveCleanupEligibleSyncOutboxSessions`
