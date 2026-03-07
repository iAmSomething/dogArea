# Backend Contract Versioning Policy v1

Date: 2026-03-07  
Issue: #417

## 목적

DogArea backend의 Edge Function / RPC 계약을 점진적으로 바꾸더라도 iOS 앱과 운영 스크립트가 깨지지 않도록 버전, 응답 envelope, fallback 수명을 고정합니다.

이 문서는 `전면 즉시 개편`이 아니라 `고위험 경로를 같은 원칙 아래에서 단계적으로 수렴`시키는 기준입니다.

## 적용 범위

우선순위가 높은 경로는 아래와 같습니다.

- `sync-walk`
- `nearby-presence`
- `rival-league`
- `quest-engine`
- widget summary RPC
  - `rpc_get_widget_territory_summary`
  - `rpc_get_widget_hotspot_summary`
  - `rpc_get_widget_quest_rival_summary`
- 호환성 민감 RPC
  - `rpc_get_rival_leaderboard`
  - `rpc_get_nearby_hotspots`

## Canonical Request Rules

### Edge Function

모든 신규/개정 Edge Function 요청은 아래 top-level 필드를 기준으로 삼습니다.

```json
{
  "version": "2026-03-07.v1",
  "request_id": "client-or-server-generated-id",
  "action": "domain_action",
  "payload": {}
}
```

규칙:

- `version`
  - 선택 필드지만, 앱이 명시할 수 있으면 항상 보냅니다.
  - 서버는 누락 시 현재 canonical contract version으로 보정합니다.
- `request_id`
  - 선택 필드지만 idempotency/추적이 필요한 요청에서는 사실상 필수로 취급합니다.
  - 기존 camelCase 요청(`requestId`, `idempotencyKey`)은 fallback alias로 허용할 수 있습니다.
- `action`
  - action router를 쓰는 함수는 필수입니다.
- `payload`
  - 도메인 데이터는 `payload` 아래에 두는 것을 기본으로 합니다.
  - 과거 top-level 필드는 호환성 기간 동안만 alias로 유지합니다.

### RPC

PostgREST 또는 앱이 직접 호출하는 RPC는 **single `payload jsonb` wrapper**를 canonical signature로 삼습니다.

예시:

```sql
select * from public.rpc_get_rival_leaderboard(
  jsonb_build_object(
    'period_type', 'week',
    'top_n', 20,
    'now_ts', now()
  )
);
```

규칙:

- 앱/REST에 노출되는 신규 RPC는 `payload jsonb`를 기본으로 합니다.
- positional arg RPC는 아래 둘 중 하나일 때만 유지합니다.
  - SQL 내부 호출만 존재하는 경우
  - 기존 운영 경로가 이미 배포되어 있고 delegate/fallback wrapper가 필요한 경우
- positional canonical이 남아 있어도, 앱/REST가 직접 호출하는 경로는 `payload jsonb` wrapper를 우선 제공합니다.

## Canonical Response Envelope

### Success

성공 응답은 아래 공통 메타 필드를 가집니다.

```json
{
  "ok": true,
  "version": "2026-03-07.v1",
  "request_id": "uuid-or-correlation-id"
}
```

도메인 데이터는 기존 top-level 키를 유지한 채 추가합니다.

```json
{
  "ok": true,
  "version": "2026-03-07.v1",
  "request_id": "req_123",
  "leaderboard": []
}
```

`data` 래핑은 강제하지 않습니다. 기존 앱 파서를 깨지 않도록 **공통 메타만 덧붙이는 방식**을 기본으로 합니다.

### Error

오류 응답은 아래 필드를 canonical로 삼습니다.

```json
{
  "ok": false,
  "error": "UNAUTHORIZED",
  "code": "UNAUTHORIZED",
  "message": "authorization header required",
  "request_id": "req_123",
  "version": "2026-03-07.v1"
}
```

규칙:

- `error`는 v1 호환성 기간 동안 legacy alias로 유지할 수 있습니다.
- `code`는 machine-readable 식별자입니다.
- `message`는 운영/로그/디버깅에 충분한 사람이 읽을 수 있는 설명입니다.
- `request_id`는 로그/DB/audit와 연결되는 상관관계 ID입니다.
- `version`은 요청이 협상한 contract version 또는 서버가 보정한 canonical version입니다.

## Breaking / Non-breaking 기준

### Non-breaking

아래는 non-breaking으로 간주합니다.

- 성공 응답에 새 필드를 추가하는 것
- 오류 응답에 `code`, `message`, `request_id`, `version`을 추가하는 것
- 기존 field alias를 유지한 채 canonical field를 추가하는 것
- RPC positional signature를 유지하면서 `payload jsonb` wrapper를 추가하는 것
- legacy route가 살아 있는 동안 canonical route를 우선 적용하는 것

### Breaking

아래는 breaking으로 간주합니다.

- 기존 top-level 필드 제거
- 기존 action 이름 제거 또는 의미 변경
- 응답의 의미를 바꾸는 필드 rename
- positional RPC를 제거하면서 wrapper/delegate도 제공하지 않는 것
- canonical route 미배포 상태에서 legacy route를 제거하는 것
- 기존에 `200`이던 경로를 schema incompatibility 때문에 `400/404/500`으로 바꾸는 것

## Deprecation / Fallback 기간 규칙

- 최소 유지 기간: **2개 앱 릴리즈 또는 14일**, 둘 중 더 긴 기간
- 운영 장애 이력이 있는 compat 경로는 **post-deploy smoke 2회 연속 통과** 전까지 제거 금지
- fallback은 `무제한 누적` 금지
  - canonical 1개
  - legacy delegate/fallback 1개
  - 최대 2계층까지만 허용
- compat 경로 제거 전에는 다음이 선행되어야 합니다.
  - 문서 업데이트
  - smoke / static check 업데이트
  - 관련 후속 이슈 또는 sunset 계획 등록

## Route / Signature 정책

### Edge route

- canonical route는 kebab-case를 사용합니다.
- legacy snake_case route는 404 fallback이 필요한 경우에만 잠정 유지합니다.
- 예: `sync-walk` canonical, `sync_walk` legacy fallback

### RPC signature

- 앱/REST direct path: `payload jsonb`
- DB 내부 delegate path: positional 허용
- compat wrapper는 `payload jsonb` -> positional delegate 또는 그 반대 중 하나로 단일화합니다.

## Request ID / Idempotency 규칙

- 쓰기 요청은 `request_id` 또는 `idempotency_key`를 최소 하나 가져야 합니다.
- 장기적으로는 `request_id`를 canonical 이름으로 삼고, `idempotency_key`는 legacy alias 또는 내부 저장 필드로 정리합니다.
- retry 가능한 write path는 request_id/idempotency_key가 로그와 DB에 남아야 합니다.

## High-risk First-wave 적용 기준

1. 계약 문서에 canonical shape를 등록한다.
2. 기존 compat/fallback을 표로 남긴다.
3. smoke 또는 static check를 연결한다.
4. runtime 전면 개편은 후속 refactor issue에서 진행한다.

즉, 이 이슈의 1차 목표는 `원칙 없는 hotfix 반복`을 끝내고, 이후 refactor가 따라야 할 단일 계약 기준을 고정하는 것입니다.

## Validation

- `swift scripts/backend_contract_versioning_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## Related

- `docs/backend-high-risk-contract-matrix-v1.md`
- `docs/sync-walk-404-fallback-policy-v1.md`
- `scripts/rival_rpc_param_compat_unit_check.swift`
- Issue `#419`, `#429`, `#436`, `#437`
