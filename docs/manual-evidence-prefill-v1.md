# Manual Evidence Prefill v1

## 목적
- 이미 생성한 manual evidence bundle을 지우지 않고, 비어 있는 공통 메타만 환경 변수로 채운다.
- blocker evidence 작업에서 반복 입력(`Date`, `Tester`, `Device / OS`, `App Build`, SMTP/DNS 운영 메타)을 줄인다.

## 엔트리포인트
- 스크립트: `bash scripts/prefill_manual_evidence_pack.sh`

## 지원 surface
- `widget`
- `auth-smtp`

## 사용법
- widget existing bundle prefill
  - `bash scripts/prefill_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence`
- auth-smtp existing bundle prefill
  - `bash scripts/prefill_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence`

## widget env
- `DOGAREA_WIDGET_EVIDENCE_DATE`
- `DOGAREA_WIDGET_EVIDENCE_TESTER`
- `DOGAREA_WIDGET_EVIDENCE_DEVICE_OS`
- `DOGAREA_WIDGET_EVIDENCE_APP_BUILD`

## auth-smtp env
- `DOGAREA_AUTH_SMTP_DATE`
- `DOGAREA_AUTH_SMTP_OPERATOR`
- `DOGAREA_AUTH_SMTP_PROJECT`
- `DOGAREA_AUTH_SMTP_PROVIDER`
- `DOGAREA_AUTH_SMTP_SENDER_DOMAIN`
- `DOGAREA_AUTH_SMTP_DNS_SPF`
- `DOGAREA_AUTH_SMTP_DNS_DKIM`
- `DOGAREA_AUTH_SMTP_DNS_DMARC`
- `DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT`
- `DOGAREA_AUTH_SMTP_HOST`
- `DOGAREA_AUTH_SMTP_PORT`
- `DOGAREA_AUTH_SMTP_USER_MASK`
- `DOGAREA_AUTH_SMTP_SENDER_NAME`
- `DOGAREA_AUTH_SMTP_SENDER_EMAIL`
- `DOGAREA_AUTH_SMTP_EMAIL_SENT`
- `DOGAREA_AUTH_SMTP_MAX_FREQUENCY`
- `DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY`
- `DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY`
- `DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY`
- `DOGAREA_AUTH_SMTP_INVITE_POLICY`

## 동작 규칙
- 이미 값이 들어 있는 줄은 덮어쓰지 않는다.
- 비어 있는 prefixed line만 채운다.
- screenshot asset, 결과 판정, 실제 mailbox/provider evidence는 채우지 않는다.

## 연결 규칙
- `manual_blocker_evidence_status.sh`는 `next-prefill-existing`를 함께 출력한다.
- bundle이 이미 존재하면 `render`보다 `prefill-existing -> validate`가 더 안전한 기본 경로다.
