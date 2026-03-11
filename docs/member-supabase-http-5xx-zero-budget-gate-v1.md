# Member Supabase HTTP 5xx Zero-Budget Gate v1

- Issue: #733
- Relates to: #732, #725, #723

## 목적
- member flow에서 Supabase HTTP route가 server-side `5xx`를 내면 즉시 차단한다.
- business/client error와 진짜 서버 장애를 분리해 읽히게 만든다.

## Canonical Gate
- live gate: `DOGAREA_RUN_SUPABASE_SMOKE=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/backend_pr_check.sh`
- direct runner: `bash scripts/run_supabase_smoke_matrix.sh`
- static guard: `swift scripts/member_supabase_http_zero_budget_gate_unit_check.swift`

## 정책
- member sweep 대상 전 route에서 `500-599`는 zero-budget이다.
- 즉, allowlist에 `5xx`를 넣지 않는다.
- 허용 가능한 기대 status는 route별로 명시적으로 적는다.
  - 예: `401`, `403`, `409`, `422`, `429`
- `4xx`는 전부 실패가 아니라, documented allowlist에 있을 때만 통과한다.

## 출력 규약
- 각 case는 아래 정보를 남긴다.
  - `case id`
  - `route`
  - `actual status`
  - `request_id` 또는 `requestId`가 있으면 함께 출력
  - `error_code` 또는 equivalent code가 있으면 함께 출력
- `5xx` 실패는 반드시 `class=server_5xx`로 찍는다.

## Allowlist Examples
- `auth.resend.signup.member_fixture` => `200,429`
- `auth.recover.member_fixture` => `200,429`
- `upload-profile-image.member_owner_mismatch` => `403`
- `sync-walk.session.invalid_payload.*` => `422`
- 그 외 canonical success path는 기본적으로 `200`

## Wiring
- manual
  - 개발자가 로컬에서 `run_supabase_smoke_matrix.sh`를 직접 실행한다.
- PR/backend check
  - `backend_pr_check.sh`에서 `DOGAREA_RUN_SUPABASE_SMOKE=1`일 때 강제된다.
- fast smoke 문맥
  - `docs/pr-fast-smoke-gate-v1.md`의 backend/sync smoke 축이 이 gate를 참조한다.
- nightly 문맥
  - `docs/nightly-full-regression-gate-v1.md`의 nearby/sync 축이 이 gate를 참조한다.

## Failure Interpretation
- `401/403`
  - auth/policy 문제 가능성 우선
- `404`
  - deploy route / rpc drift 문제 가능성 우선
- `409/422`
  - business/schema/fixture 문제로 분류
- `5xx`
  - 서버 코드 또는 DB/runtime 문제로 즉시 fail
