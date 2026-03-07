# Backend Edge Error Taxonomy v1

Date: 2026-03-07  
Issue: #418

## 목적

Edge Function마다 제각각 쓰이던 `error`, `errorCode`, message를 운영/QA/배포 검증이 같은 분류로 읽을 수 있게 정규화합니다.

## Canonical Error Categories

### 1. auth

인증/권한/세션 관련 실패.

대표 코드:

- `UNAUTHORIZED`
- `AUTH_HEADER_MISSING`
- `AUTH_TOKEN_EMPTY`
- `AUTH_SESSION_INVALID`
- `UNAUTHORIZED_USER_MISMATCH`
- `AUTH_MODE_NOT_ALLOWED`

### 2. contract

요청 형식이나 action/stage/version 계약 불일치.

대표 코드:

- `METHOD_NOT_ALLOWED`
- `INVALID_JSON`
- `ACTION_REQUIRED`
- `STAGE_REQUIRED`
- `UNSUPPORTED_ACTION`
- `UNSUPPORTED_STAGE`
- `INVALID_VERSION`
- `CONTRACT_SHAPE_MISMATCH`

### 3. validation

도메인 입력값 자체가 잘못된 경우.

대표 코드:

- `INVALID_PAYLOAD`
- `INVALID_PET_ID`
- `PET_NAME_REQUIRED`
- `INVALID_AGE_RANGE`
- `OWNER_ID_REQUIRED`
- `INVALID_OWNER_ID`
- `INVALID_IMAGE_BASE64`
- `INVALID_IMAGE_SIZE`

### 4. unavailable

배포 누락, RPC 미배포, 설정 누락, 일시 unavailable.

대표 코드:

- `SERVER_MISCONFIGURED`
- `FUNCTION_NOT_DEPLOYED`
- `RPC_NOT_FOUND`
- `COOLDOWN_ACTIVE`
- `RATE_LIMITED`
- `SERVICE_UNAVAILABLE`

### 5. privacy

privacy guard / suppression / visibility policy 관련 차단 또는 마스킹.

대표 코드:

- `LOCATION_SHARING_DISABLED`
- `PRIVACY_GUARD_BLOCKED`
- `HOTSPOT_SUPPRESSED_K_ANON`
- `HOTSPOT_SUPPRESSED_SENSITIVE_MASK`
- `LIVE_PRESENCE_DELAYED`

### 6. upstream

DB, Storage, provider, RPC 등 외부 의존성 실패.

대표 코드:

- `RPC_FAILED`
- `DB_WRITE_FAILED`
- `DB_READ_FAILED`
- `STORAGE_UPLOAD_FAILED`
- `PUBLIC_URL_FAILED`
- `UPSTREAM_TIMEOUT`
- `ALL_PROVIDERS_FAILED`
- `SOURCE_IMAGE_NOT_FOUND`

### 7. abuse

anti-abuse / sanction / moderation에 의해 제한된 경우.

대표 코드:

- `ABUSE_BLOCKED`
- `SANCTION_ACTIVE`
- `MODERATION_BLOCKED`

## Response Mapping Rule

- legacy `error` 필드는 유지 가능
- canonical machine-readable 값은 `code`에 둡니다
- `message`는 운영자 해석에 충분한 설명을 넣습니다
- 가능한 경우 `category`는 로그/문서에서 유추 가능해야 합니다

예시:

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

## Category-to-runbook 연결

- `auth` -> 세션/Authorization 헤더/anon retry 확인
- `contract` -> payload/version/action/stage와 compat matrix 확인
- `validation` -> caller payload 검증 실패 확인
- `unavailable` -> 배포 매트릭스, migration drift, cooldown 확인
- `privacy` -> suppression / visibility / audit log 확인
- `upstream` -> RPC/Storage/provider dependency 확인
- `abuse` -> sanction / anti-abuse guard 확인

## Current Mapping Guidance

현재 함수가 `error`만 반환하더라도, 운영 문서/후속 refactor에서는 아래처럼 읽습니다.

- `METHOD_NOT_ALLOWED`, `INVALID_JSON`, `ACTION_REQUIRED`, `UNSUPPORTED_ACTION`, `UNSUPPORTED_STAGE` -> `contract`
- `INVALID_PAYLOAD`, `INVALID_PET_ID`, `PET_NAME_REQUIRED` 등 -> `validation`
- `SERVER_MISCONFIGURED`, `404`, `cooldown` -> `unavailable`
- DB/RPC/Storage/provider message -> `upstream`

## Validation

- `swift scripts/backend_edge_observability_unit_check.swift`
