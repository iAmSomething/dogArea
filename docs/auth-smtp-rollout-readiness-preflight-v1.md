# Auth SMTP Rollout Readiness Preflight v1

- Issue: #756
- Relates to: #482

## 목적
- custom SMTP rollout 전에 `지금 바로 외부 작업을 시작해도 되는지`를 한 번에 판단한다.
- provider / sender domain / SMTP 입력값 / DNS claim / evidence pack 상태를 한 번에 점검한다.
- `문서는 있는데 실제 준비도는 불명확한 상태`를 줄인다.

## 엔트리포인트
- 스크립트: `bash scripts/auth_smtp_rollout_readiness_check.sh`

## 입력 계약
환경 변수:
- `DOGAREA_AUTH_SMTP_PROJECT`
- `DOGAREA_AUTH_SMTP_PROVIDER`
- `DOGAREA_AUTH_SMTP_SENDER_DOMAIN`
- `DOGAREA_AUTH_SMTP_HOST`
- `DOGAREA_AUTH_SMTP_PORT`
- `DOGAREA_AUTH_SMTP_USER_MASK`
- `DOGAREA_AUTH_SMTP_SENDER_NAME`
- `DOGAREA_AUTH_SMTP_SENDER_EMAIL`
- `DOGAREA_AUTH_SMTP_DNS_SPF`
- `DOGAREA_AUTH_SMTP_DNS_DKIM`
- `DOGAREA_AUTH_SMTP_DNS_DMARC`

선택 인자:
- `--evidence <path>`

기본 evidence 경로:
- `.codex_tmp/auth-smtp-evidence-pack.md`

## 출력 계약
- `title`
- `issue`
- `evidence-pack`
- `config-inputs`
- `missing-config-vars`
- `dns-claims`
- `missing-dns-claims`
- `evidence-status`
- `overall`
- `next-evidence-runbook`
- `next-live-send-matrix`
- `next-validate`
- `next-render-closure`
- `next-post-closure`

## 상태 의미
- `config-inputs`
  - `ready`
  - `missing`
- `dns-claims`
  - `ready`
  - `missing`
- `evidence-status`
  - `missing`
  - `incomplete`
  - `complete`
- `overall`
  - `blocked:missing-config`
  - `blocked:dns-unverified`
  - `ready-for-live-send-evidence`
  - `ready-to-post`

## 운영 규칙
- 이 스크립트는 실제 Supabase Dashboard 값을 읽지 않는다.
- operator가 입력한 rollout 준비값과 evidence file 상태를 기준으로 readiness를 요약한다.
- `ready-to-post`는 evidence pack까지 완결된 상태를 뜻한다.
- secret 평문은 환경 변수나 evidence 파일에 남기지 않는다. `SMTP User Mask` 수준만 남긴다.
