# Walk Sync Consistency Outbox v1 (P1)

## 1. 목적
산책 기록은 항상 로컬에 남기고, 원격 동기화는 실패해도 아웃박스 큐로 재시도해 eventually consistent 상태로 수렴시킨다.

## 2. 원칙
- 로컬 저장(CoreData) 성공 = 사용자 기록 성공
- 원격 동기화 실패는 사용자 기록 실패로 간주하지 않음
- 재전송은 `session -> points -> meta` 순서 보장
- 동일 세션 재전송은 `idempotency_key` 기반 중복 방지

## 3. 아웃박스 모델
- 저장소: `UserDefaults` (`sync.outbox.items.v1`)
- item 필드
  - `walkSessionId`
  - `stage(session|points|meta)`
  - `idempotencyKey`
  - `payload`
  - `status(queued|retrying|processing|permanentFailed|completed)`
  - `retryCount`, `nextRetryAt`, `lastErrorCode`

## 4. 오류 코드 표준화
- retryable
  - `offline`
  - `token_expired`
  - `server_error`
  - `not_configured`
  - `unknown`
- non-retryable
  - `unauthorized`
  - `schema_mismatch`
  - `storage_quota`
  - `conflict` (멱등 충돌은 성공 처리로 수렴 가능)

## 5. 재시도 정책
- 온라인/활성 시점에 순차 flush 수행
- 앱 활성화(`didBecomeActive`) 및 주기 tick(5초)에서 flush 트리거
- 실패 시 exponential backoff
  - 기본 5초, 최대 15분
- 첫 실패 지점에서 flush 중단해 순서 보장

## 6. 이미지 저장 실패 분리
- 지도 이미지가 없더라도 세션/포인트 저장은 진행
- `meta` stage에서 `hasImage=false`로 동기화해 후속 보정 가능

## 7. 토큰 만료 대응
- `401/403`은 `token_expired`로 분류
- 로컬 큐 보존 후 재인증 이후 flush 재개

## 8. QA 체크 포인트
- 오프라인 저장 후 재연결 시 큐가 순차 소진되는지
- 동일 세션 재전송에도 중복 insert 없이 수렴하는지
- 이미지 미생성 상태에서도 세션 저장이 차단되지 않는지
- 토큰 만료 오류 이후 재인증 시 재동기화 재개되는지
