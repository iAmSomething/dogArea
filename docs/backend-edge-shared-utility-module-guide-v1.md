# Backend Edge Shared Utility Module Guide v1

Date: 2026-03-07  
Issue: #438

## 목적

Edge Function마다 `json()` 응답 helper, 기본 파서, Supabase env preflight를 따로 들고 있으면
작은 편차가 다시 누적됩니다.

이 문서는 `_shared` 모듈의 책임을 고정합니다.

## Shared Module Inventory

| Module | Responsibility | Notes |
| --- | --- | --- |
| `supabase/functions/_shared/http.ts` | JSON 응답, 공통 에러 응답, `POST` body parse | `json`, `errorJson`, `methodNotAllowed`, `parseJsonBody` |
| `supabase/functions/_shared/parsers.ts` | 문자열/레코드/숫자/불리언/UUID 파싱 | business rule이 아닌 transport parse만 담당 |
| `supabase/functions/_shared/edge_runtime.ts` | `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` preflight | env 누락 시 `SERVER_MISCONFIGURED`로 통일 |
| `supabase/functions/_shared/edge_auth.ts` | auth header parsing / validation preflight | auth 정책 surface는 여기서 유지 |
| `supabase/functions/_shared/request_keys.ts` | request metadata canonicalization | `request_id`, `idempotency_key` canonical rule |
| `supabase/functions/_shared/storage_upload.ts` | storage 업로드 path/public URL helper | image/storage 계열 전용 |

## Applied in #438

우선 적용 대상:

- `feature-control`
- `quest-engine`
- `upload-profile-image`
- `sync-profile`
- `rival-league`

적용 내용:

- local `json()` 제거
- local `asString`, `asRecord`, `toNumber`, `toBoolean`, `toNullableInt`, `toUUIDOrNull` 제거
- local Supabase env preflight 제거

## Deferred

이번 사이클에서 전면 전환하지 않은 함수:

- `sync-walk`
- `nearby-presence`
- `caricature`

이유:

- `sync-walk`, `nearby-presence`는 이미 feature-local `support/` 구조로 잘게 분해돼 있어, 추가 전환 시 handler 레이어까지 같이 만질 가능성이 큽니다.
- `caricature`는 `errorCode` / provider fallback / observability shape가 다른 함수보다 특수해서 공통 HTTP helper를 성급히 얹으면 응답 contract를 건드릴 수 있습니다.

즉, 이번 이슈는 **공통 transport helper를 안전한 함수부터 흡수하는 1차 정리**입니다.

## Module Usage Rules

### `http.ts`

사용:

- 단순 `{ error: ... }` envelope를 쓰는 함수
- `INVALID_JSON`, `METHOD_NOT_ALLOWED` 같은 공통 transport 에러

주의:

- `caricature`처럼 `errorCode` 기반 응답 contract가 다른 함수에는 즉시 강제 적용하지 않습니다.

### `parsers.ts`

사용:

- transport payload parse
- trim / UUID / boolean / integer coercion

비범위:

- domain normalization
- product rule
- DB schema rule

예:

- `normalizeGender` 같은 도메인 의미는 각 함수가 유지

### `edge_runtime.ts`

사용:

- Supabase env 누락 preflight가 필요한 함수

목표:

- env 누락 시 함수별 편차 없이 `SERVER_MISCONFIGURED` 반환

### `edge_auth.ts`

역할:

- auth header parsing
- anon/member/service-role policy resolution

이번 이슈는 auth helper를 새로 만드는 것이 아니라, 기존 `edge_auth.ts`를 shared auth preflight의 source of truth로 재확인하는 작업입니다.

## Validation

- `swift scripts/backend_edge_shared_utility_module_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## Related

- `docs/backend-edge-auth-policy-v1.md`
- `docs/backend-request-correlation-idempotency-policy-v1.md`
- `docs/backend-edge-observability-standard-v1.md`
- `#419`
- `#417`
- `#418`

