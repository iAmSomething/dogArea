# Backend Edge Auth Policy v1

Date: 2026-03-07  
Issue: #419

## 목적

DogArea Supabase Edge Function이 함수마다 bearer 파싱, `auth.getUser`, 401/403 응답을 복붙하지 않도록 공통 인증 계층과 정책 매핑을 고정합니다.

이 문서는 앱의 401 retry 정책을 바꾸는 문서가 아니라, **서버 함수가 어떤 인증 모드를 기대하는지 선언적으로 관리**하기 위한 기준입니다.

## 공통 helper

- 파일: `supabase/functions/_shared/edge_auth.ts`

helper 책임:

- bearer header 파싱
- 빈 토큰 / 손상 토큰 처리
- member token 검증 (`auth.getUser`)
- anon key 허용 함수 분기
- service-role internal 분기
- 공통 401/403 응답 포맷 생성
- sync-profile용 user mismatch 403 helper 제공

운영 규칙:

- helper로 인증을 직접 처리하는 함수는 gateway `verify_jwt`를 끕니다.
- 이유: 현재 프로젝트는 **정적 anon JWT + 비대칭 member access token**이 공존하므로, gateway 레이어에서 member token을 먼저 `Invalid JWT`로 차단하면 함수 내부 공통 정책이 동작하지 않습니다.
- 설정 파일: `supabase/config.toml`

## 정책 종류

### 1. `member_required`

member bearer token이 필수입니다.

규칙:

- 빈/malformed bearer -> `401`
- anon key bearer -> `401`
- invalid member token -> `401`
- user mismatch 같은 소유권 오류 -> `403`

대상:

- `sync-walk`
- `sync-profile`
- `rival-league`
- `quest-engine`
- `caricature`

### 2. `member_or_anon`

member token 또는 app/anon bearer를 허용합니다.

규칙:

- anon key는 `anon` auth mode로 허용
- member token은 검증 후 `authenticated` auth mode로 허용
- invalid member token은 `401`
- 정책상 anon 허용 함수라도 malformed/empty bearer는 `401`

대상:

- `nearby-presence`
- `upload-profile-image`
- `feature-control`

### 3. `service_role_internal`

외부 앱 호출이 아니라 internal/service-role 호출 전용입니다.

현재 helper에서 지원만 정의하고, 이번 1차 적용 함수는 없습니다.

## 공통 401/403 응답 규칙

401/403은 아래 메타를 공통으로 가집니다.

```json
{
  "ok": false,
  "error": "UNAUTHORIZED",
  "code": "AUTH_SESSION_INVALID",
  "message": "member token validation failed",
  "function_name": "sync-walk",
  "request_id": "req_123",
  "version": "2026-03-07.v1",
  "auth_mode": "unknown",
  "policy": "member_required",
  "fallback_used": false
}
```

규칙:

- `error`는 legacy 호환성을 위해 유지
- `code`는 machine-readable auth failure reason
- `function_name`, `request_id`, `policy`, `auth_mode`를 함께 노출
- `sync-profile`의 user mismatch는 `403` + `UNAUTHORIZED_USER_MISMATCH`

## auth error code

- `AUTH_HEADER_MISSING`
- `AUTH_TOKEN_EMPTY`
- `AUTH_SESSION_INVALID`
- `AUTH_MODE_NOT_ALLOWED`
- `UNAUTHORIZED_USER_MISMATCH`

## 함수별 정책 매핑

| Function | Policy | Notes |
| --- | --- | --- |
| `sync-walk` | `member_required` | 산책 동기화는 member ownership 필수 |
| `sync-profile` | `member_required` | `user_id` mismatch는 403 |
| `rival-league` | `member_required` | 라이벌 데이터는 member 권리경로 |
| `quest-engine` | `member_required` | 퀘스트 진행/클레임은 member 권리경로 |
| `caricature` | `member_required` | 과거 optional auth 경로 제거, member 검증 필수화 |
| `nearby-presence` | `member_or_anon` | app authorization policy 유지 |
| `upload-profile-image` | `member_or_anon` | member는 `auth.user.id` owner binding 강제, anon은 `anon-onboarding-*` 임시 namespace만 허용 |
| `feature-control` | `member_or_anon` | rollout/flag app authorization 유지 |

위 표에 포함된 함수는 모두 `supabase/config.toml`에서 `verify_jwt = false`를 유지합니다.

## 403 사용 기준

403은 인증은 되었지만 **요청 대상 소유권이 맞지 않는 경우**에만 사용합니다.

현재 1차 적용:

- `sync-profile`의 `user_id` mismatch
- `upload-profile-image`의 `ownerId` mismatch

즉, invalid token / empty token / anon not allowed는 전부 `401`, 소유권 mismatch만 `403`으로 분리합니다.

## Validation

- `swift scripts/backend_edge_auth_unification_unit_check.swift`
- `swift scripts/auth_401_refresh_retry_unit_check.swift`
- `swift scripts/auth_http_401_session_invalidation_unit_check.swift`
- `swift scripts/auth_edge_function_anon_retry_unit_check.swift`
- `supabase/config.toml`의 대상 함수 `verify_jwt = false`
- `DOGAREA_AUTH_SMOKE_ITERATIONS=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/auth_member_401_smoke_check.sh`

## Related

- `supabase/functions/_shared/edge_auth.ts`
- `docs/backend-edge-auth-mode-inventory-v1.md`
- `docs/backend-edge-secret-inventory-rotation-runbook-v1.md`
- `docs/backend-contract-versioning-policy-v1.md`
- `docs/backend-edge-observability-standard-v1.md`
- `#418`
- `#431`
