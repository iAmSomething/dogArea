# Backend Request Correlation / Idempotency Policy v1

Date: 2026-03-07  
Issue: #426

## 목적

DogArea backend 경계에서 `request_id`, `idempotency_key`, `event_id`, `action_id`의 역할을 분리해,
중복 처리와 장애 추적 시 어떤 키를 기준으로 봐야 하는지 고정합니다.

## Canonical Rule

### 1. `request_id`

요청 상관관계용 키입니다.

규칙:
- 함수 로그/응답/에러에서 같은 요청을 묶는 기준입니다.
- 재시도 시 동일 값을 재사용할 수 있지만, **주 목적은 correlation**입니다.
- canonical 이름은 `request_id`입니다.
- legacy alias는 `requestId`, `action_id`를 허용합니다.

### 2. `idempotency_key`

재전송 중복 방지용 키입니다.

규칙:
- retry 가능한 write path에서 canonical 이름은 `idempotency_key`입니다.
- legacy alias는 `idempotencyKey`를 허용합니다.
- 경로 특성상 별도 키가 없으면 `request_id`를 fallback으로 사용할 수 있습니다.

### 3. `event_id`

도메인 원장용 이벤트 키입니다.

규칙:
- quest progress처럼 원장/ledger가 `event_id`를 유니크 키로 쓰는 경우 유지합니다.
- transport canonical 이름은 여전히 `idempotency_key`지만,
  quest ingest 경로에서는 `event_id`를 최종 RPC 필드로 사용합니다.
- `idempotency_key`가 들어오면 `event_id`로 매핑할 수 있습니다.

### 4. `action_id`

watch/widget 같은 로컬 transport의 액션 dedupe 키입니다.

규칙:
- 앱 내부 transport에서는 유지할 수 있습니다.
- backend 경계를 넘을 때는 `request_id` 또는 `idempotency_key`로 번역합니다.
- backend canonical field로 직접 확장하지 않습니다.

## 고위험 경로 표준

### `sync-walk`
- canonical request key: `request_id`
- canonical idempotency key: `idempotency_key`
- legacy alias: `requestId`, `idempotencyKey`
- stage write 응답은 `request_id`와 `idempotency_key`를 함께 반환할 수 있습니다.

### `nearby-presence`
- canonical request key: `request_id`
- canonical idempotency key: `idempotency_key`
- legacy alias: `requestId`, `idempotencyKey`, `action_id`
- `upsert_presence` / `upsert_live_presence`는 `idempotency_key`를 live presence RPC에 전달합니다.
- hotspot / live presence read 응답은 `request_id`를 반환해 trace를 고정합니다.

### `quest-engine`
- canonical request key: `request_id`
- canonical idempotency key: `idempotency_key`
- legacy alias: `requestId`, `action_id`
- `claim_reward`는 canonical `request_id`를 reward claim RPC에 전달합니다.
- `ingest_walk_event`는 canonical transport key를 받아 최종 `event_id`로 매핑할 수 있습니다.
- legacy alias `instanceId`, `target_instance_id`, `eventId`도 계속 허용합니다.

### widget / watch action bridge
- 앱 내부 dedupe는 `action_id` 유지
- backend 함수 호출 시 `request_id` 또는 `idempotency_key`로 번역
- bridge 문서/코드에서는 `action_id -> request_id` 변환을 표준으로 간주

## Helper

공통 helper:
- `supabase/functions/_shared/request_keys.ts`

helper 책임:
- canonical `request_id` 선택
- canonical `idempotency_key` 선택
- legacy alias fallback 정리

## Validation

- `swift scripts/backend_request_id_idempotency_unit_check.swift`
- `swift scripts/backend_contract_versioning_unit_check.swift`
- `swift scripts/backend_edge_observability_unit_check.swift`
- `deno check supabase/functions/sync-walk/index.ts`
- `deno check supabase/functions/nearby-presence/index.ts`
- `deno check supabase/functions/quest-engine/index.ts`

## Related

- `docs/backend-contract-versioning-policy-v1.md`
- `docs/backend-high-risk-contract-matrix-v1.md`
- `docs/watch-connectivity-reliability-v1.md`
- `#420`
