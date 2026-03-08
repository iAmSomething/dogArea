# Backend Edge Secret Inventory / Rotation Runbook v1

Date: 2026-03-07  
Issue: #435

## 목적

DogArea backend에서 사용하는 credential을 모두 같은 "secret"으로 취급하면 운영 판단이 흐려집니다.

이 문서는 아래를 구분해 고정합니다.

- 진짜 비밀이어야 하는 secret
- 앱에 배포되는 public credential
- secret은 아니지만 운영에 필수인 runtime config
- 각 credential이 어떤 함수/플랫폼 surface에서 쓰이는지
- rotation / 유출 대응 / 검증 절차

## 분류 원칙

### 1. `runtime_config`

비밀이 아니라 endpoint/식별용 구성값입니다.

대표:

- `SUPABASE_URL`
- `PROJECT_REF`

### 2. `public_client_credential`

앱에 실려도 되는 publishable credential이지만, 회전 비용과 blast radius가 있습니다.

대표:

- `SUPABASE_ANON_KEY`

중요:

- `SUPABASE_ANON_KEY`는 **service role secret과 같은 수준의 비밀키가 아닙니다.**
- 다만 anon auth path와 smoke, 앱 번들, Edge auth helper에 영향이 있으므로 inventory에는 포함합니다.

### 3. `edge_runtime_secret`

Edge Function runtime에만 있어야 하는 비밀입니다.

대표:

- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENAI_API_KEY`
- `GEMINI_API_KEY`

### 4. `platform_secret`

Edge Function 바깥의 hosted Supabase/Auth/Storage 플랫폼 설정에 필요한 비밀입니다.

대표:

- `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET`
- `S3_SECRET_KEY`
- custom SMTP credentials

## Credential Inventory

| Credential | Class | Scope | Current source | Rotation owner | Rotation trigger | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `SUPABASE_URL` | `runtime_config` | app + Edge + scripts | iOS xcconfig / Edge env | backend operator | project ref/domain migration | secret 아님 |
| `PROJECT_REF` | `runtime_config` | app config / smoke output | xcconfig / scripts | backend operator | project migration | secret 아님 |
| `SUPABASE_ANON_KEY` | `public_client_credential` | app bundle + Edge member validation helper + smoke scripts | iOS xcconfig / Edge env | backend operator + mobile release owner | anon auth abuse, signing/issuer change, project reset | 앱 배포 coordination 필요 |
| `SUPABASE_SERVICE_ROLE_KEY` | `edge_runtime_secret` | service-role proxy Edge 함수 | Edge env only | backend operator | suspected leak, personnel/device incident, project reset | app 금지 |
| `OPENAI_API_KEY` | `edge_runtime_secret` | `caricature` provider path | Edge env only | backend operator | provider leak/abuse, billing incident, planned rotation | `caricature` only |
| `GEMINI_API_KEY` | `edge_runtime_secret` | `caricature` provider path | Edge env only | backend operator | provider leak/abuse, billing incident, planned rotation | canonical Gemini key |
| `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` | `platform_secret` | Supabase Auth Apple provider | hosted auth config | backend operator | Apple secret expiry / auth incident | Edge 함수 직접 의존 아님 |
| `S3_SECRET_KEY` | `platform_secret` | hosted storage analytics/vector config | hosted platform config | backend operator | infra secret rotation | currently optional |
| SMTP credentials | `platform_secret` | Supabase Auth custom SMTP | hosted auth config | backend operator | email provider rotation / auth deliverability incident | built-in SMTP 사용 중이면 비활성 |

## Edge Function Secret Mapping

| Edge Function | Required runtime config | Public credential | Edge runtime secret | Optional / legacy | Failure mode when missing |
| --- | --- | --- | --- | --- | --- |
| `sync-walk` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | none | none | `SERVER_MISCONFIGURED` |
| `sync-profile` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | none | none | `SERVER_MISCONFIGURED` |
| `rival-league` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | none | none | `SERVER_MISCONFIGURED` |
| `quest-engine` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | none | none | `SERVER_MISCONFIGURED` |
| `nearby-presence` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | `SUPABASE_SERVICE_ROLE_KEY` | none | `SERVER_MISCONFIGURED` |
| `feature-control` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | `SUPABASE_SERVICE_ROLE_KEY` | none | `SERVER_MISCONFIGURED` |
| `upload-profile-image` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | `SUPABASE_SERVICE_ROLE_KEY` | none | `SERVER_MISCONFIGURED` |
| `caricature` | `SUPABASE_URL` | `SUPABASE_ANON_KEY` | `SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY` | none | missing Supabase secret => `SERVER_MISCONFIGURED`, missing provider key => provider fallback or `ALL_PROVIDERS_FAILED` |

## Function-by-Function Notes

### `sync-walk`, `sync-profile`, `rival-league`, `quest-engine`

- 현재는 `SUPABASE_URL`, `SUPABASE_ANON_KEY`만 직접 읽습니다.
- member token 검증은 `edge_auth.ts`가 anon key 기반 user client로 수행합니다.
- 즉, service role이 없어도 동작하는 member-required edge surface입니다.

### `nearby-presence`, `feature-control`, `upload-profile-image`

- member/app policy를 받으면서 service-role proxy write/read를 수행합니다.
- 따라서 `SUPABASE_SERVICE_ROLE_KEY` 유출은 이 세 함수에 직접 고위험입니다.

### `caricature`

- storage/db update용 `SUPABASE_SERVICE_ROLE_KEY`
- provider call용 `OPENAI_API_KEY`
- provider call용 `GEMINI_API_KEY`

핵심:

- `GEMINI_API_KEY`가 canonical입니다.
- Gemini secret 이름은 `GEMINI_API_KEY` 하나만 사용합니다.

## Rotation Baseline

### `SUPABASE_SERVICE_ROLE_KEY`

- baseline: 정기 forced rotation보다 **event-driven emergency rotation** 우선
- recommended review cadence: 분기 1회 inventory review
- immediate rotation triggers:
  - 로그/스크린샷/채팅/PR에 노출
  - 개발 장비 분실
  - CI secret 노출 의심
  - 프로젝트 소유권 이전

검증:

- affected Edge function deploy/reload 확인
- `bash scripts/backend_pr_check.sh`
- member/app smoke 재실행

### `SUPABASE_ANON_KEY`

- baseline: public credential이므로 "유출" 자체보다 **abuse / issuer 변경 / project reset**가 rotation trigger
- coordination cost가 큼:
  - iOS 번들/xcconfig
  - smoke harness
  - Edge anon validation helper

즉시 rotation trigger:

- anon auth abuse
- project JWT issuer/signing 변경
- wrong project key 배포

### Provider keys (`OPENAI_API_KEY`, `GEMINI_API_KEY`)

- recommended cadence: 분기 1회 또는 provider 정책에 맞춘 계획 교체
- immediate rotation triggers:
  - provider dashboard compromise signal
  - 비정상 과금/쿼터 급증
  - key가 로그나 노트에 노출

### `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET`

- expiry-driven rotation
- Apple provider secret 만료 전 사전 교체
- auth regression smoke와 login 검증이 동반되어야 함

## Rotation Procedure

### 1. 분류

먼저 대상이 아래 중 무엇인지 구분합니다.

- public credential (`SUPABASE_ANON_KEY`)
- edge runtime secret (`SUPABASE_SERVICE_ROLE_KEY`, provider keys)
- platform secret (Apple/Auth/SMTP/S3)

### 2. 영향 함수 식별

이 문서의 function mapping에서 영향을 받는 surface를 먼저 확정합니다.

예:

- `SUPABASE_SERVICE_ROLE_KEY` -> `nearby-presence`, `feature-control`, `upload-profile-image`, `caricature`
- `OPENAI_API_KEY` -> `caricature`
- `SUPABASE_ANON_KEY` -> app bundle + auth smoke + member validation helper

### 3. 새 값 반영

반영 위치:

- hosted dashboard secrets
- local/CI secure secret store
- 필요한 경우 iOS xcconfig / 배포 파이프라인 변수

원칙:

- 저장소에 값 commit 금지
- screenshot / issue body / PR body에 secret 직접 기록 금지

### 4. 재배포 / 재적용

필요 시:

- affected Edge function redeploy
- smoke harness env 갱신
- mobile app config 갱신

### 5. 검증

기본 검증:

```bash
bash scripts/backend_pr_check.sh
```

live auth/function smoke:

```bash
DOGAREA_RUN_SUPABASE_SMOKE=1 \
DOGAREA_TEST_EMAIL=... \
DOGAREA_TEST_PASSWORD=... \
bash scripts/backend_pr_check.sh
```

member/app auth surface:

```bash
DOGAREA_AUTH_SMOKE_ITERATIONS=1 \
DOGAREA_TEST_EMAIL=... \
DOGAREA_TEST_PASSWORD=... \
bash scripts/auth_member_401_smoke_check.sh
```

### 6. 후처리

- old value 제거 확인
- secret inventory 변경분 문서화
- incident timeline과 affected surface 기록

## Failure Mode Inventory

| Credential missing/invalid | Expected impact |
| --- | --- |
| `SUPABASE_URL` missing | 대상 함수 `SERVER_MISCONFIGURED` |
| `SUPABASE_ANON_KEY` missing | 대상 함수 `SERVER_MISCONFIGURED` 또는 `edge_auth` validation unusable |
| `SUPABASE_SERVICE_ROLE_KEY` missing | service-role proxy 함수 `SERVER_MISCONFIGURED` |
| `OPENAI_API_KEY` missing | `caricature` OpenAI provider only 실패, Gemini가 있으면 fallback 가능 |
| `GEMINI_API_KEY` missing | `caricature` Gemini provider only 실패, OpenAI가 있으면 fallback 가능 |
| provider keys 모두 unusable | `caricature` -> `ALL_PROVIDERS_FAILED` |
| `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` invalid | Apple 로그인/토큰 교환 경로 실패 |

## Gemini Provider Key Policy

- canonical key: `GEMINI_API_KEY`
- 저장소, 문서, hosted secret 설정 이름은 `GEMINI_API_KEY`로 단일화합니다.
- legacy alias는 `#479`에서 제거되었습니다.

## Incident Rules

1. `SUPABASE_SERVICE_ROLE_KEY` 노출은 highest severity로 간주
2. `SUPABASE_ANON_KEY` 노출은 secret breach가 아니라 public credential incident로 분류
3. provider key incident는 billing/provider abuse 모니터링과 함께 본다
4. secret rotation 후 smoke 없는 머지는 금지

## Validation

- `swift scripts/backend_edge_secret_inventory_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## Related

- `docs/backend-edge-incident-runbook-v1.md`
- `docs/backend-edge-auth-policy-v1.md`
- `docs/supabase-auth-apple-plan.md`
- `docs/image-provider-router-v1.md`
- `scripts/auth_member_401_smoke_check.sh`
