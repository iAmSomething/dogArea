# Auth SMTP Closure Checklist v1

- Issue: #670
- Relates to: #482

## 목적
- `#482`를 닫기 전에 무엇이 채워져 있어야 하는지 한 문서에 고정한다.
- 운영 증적이 있어도 마지막 종료 판정 기준이 흩어져 있는 문제를 없앤다.

## 선행 문서
- provider / DNS / secret checklist: `docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md`
- rollout evidence runbook: `docs/auth-smtp-rollout-evidence-runbook-v1.md`
- live-send validation matrix: `docs/auth-smtp-live-send-validation-matrix-v1.md`
- rollout evidence bundle template: `docs/auth-smtp-rollout-evidence-template-v1.md`

## 필수 체크리스트
- provider 선택이 문서화돼 있다.
- sender domain verification 증적이 있다.
  - SPF pass
  - DKIM verified
  - DMARC record 존재
- Supabase Auth SMTP settings 증적이 있다.
  - `SMTP Host`
  - `SMTP Port`
  - `SMTP User Mask`
  - `Sender Name`
  - `Sender Email`
  - `email_sent`
  - `auth.email.max_frequency`
- production 또는 rollout 대상 환경에서 아래 positive case가 모두 채워져 있다.
  - `SMTP-001`
  - `SMTP-002`
  - `SMTP-003`
- 아래 negative/guard evidence가 최소 1개 이상 있다.
  - `SMTP-101`
  - `SMTP-102`
  - `SMTP-103`
- 각 케이스마다 아래가 남아 있다.
  - `accepted`
  - `mailbox_received`
  - `redirect_valid`
  - `provider_event_checked`
  - `provider_message_id`
- rollback / rotation readiness가 기록돼 있다.
  - rollback path
  - secret rotation owner
  - tested backup path
- secret이 평문으로 남지 않았다.

## 종료 판정
- 위 항목이 모두 채워졌고 남은 blocker가 없으면 `#482`를 닫아도 된다.
- 실수신 증거 없이 provider dashboard 캡처만 있는 상태는 종료 불가다.
- staging만 있고 production evidence가 없으면 종료 불가다.

## 운영 규칙
- provider 교체, sender domain 변경, hosted auth SMTP 값 변경 시 이 체크리스트를 다시 확인한다.
- 종료 코멘트는 `docs/auth-smtp-closure-comment-template-v1.md` 형식을 사용한다.
