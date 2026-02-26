# Guest Data Upgrade Flow v1 (Issue #76)

## 목표
- 로그인 직후 로컬 게스트 산책 데이터를 회원 계정으로 안전하게 승격한다.
- 동일 데이터 재실행 시 중복 적재/중복 반영 없이 멱등적으로 수렴한다.
- 실패 시 데이터 손실 없이 재시도 가능 상태를 유지한다.

## 구현 요약
1. 감지
- 로그인 완료 시 `GuestDataUpgradeService.pendingPrompt(for:)`로 로컬 스냅샷을 계산한다.
- 스냅샷(`sessionCount`, `pointCount`, `area`, `duration`, `signature`)이 있고,
  사용자별 완료 signature와 다르면 가져오기 시트를 띄운다.

2. 이관
- 각 로컬 폴리곤(session)을 `SyncOutboxStore.enqueueWalkStages`로
  `session -> points -> meta` 3단계 큐에 적재한다.
- `idempotencyKey = walk-{sessionId}-{stage}` 를 재사용한다.
- 큐 flush를 즉시 1회 실행하고 결과를 리포트로 저장한다.

3. 재시도
- 영구실패 항목은 `requeuePermanentFailures`로 재큐잉 가능.
- 로그인 후 이전 리포트에 미처리 항목이 있으면 시트가 재시도 모드로 노출된다.

4. 결과 피드백
- `RootView` 상단 배너: 진행중/완료/재시도 상태 표시
- `HomeView` 카드: 최근 이관 리포트(세션/포인트/면적) 표시

## 멱등성 규칙
- 로컬 큐 적재는 동일 `idempotencyKey`가 이미 있으면 상태와 무관하게 재적재하지 않는다.
- 서버 측 중복 충돌(409)은 성공으로 간주해 누적값 왜곡을 방지한다.

## 저장 키
- 리포트: `guest.data.upgrade.report.v1.<stableUserKey>`
- 완료 signature: `guest.data.upgrade.signature.v1.<stableUserKey>`

## QA 체크
- [ ] 게스트 산책 데이터 보유 상태에서 로그인 시 가져오기 시트 노출
- [ ] 가져오기 실행 후 리포트/배너/홈 카드 갱신
- [ ] 동일 데이터 재실행 시 outbox 중복 적재 없음
- [ ] 실패 후 재시도로 상태 회복 가능
