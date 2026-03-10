# Auth SMTP Live-Send Validation Matrix v1

- Issue: #666
- Relates to: #482

## 목적
- custom SMTP rollout 직전에 어떤 실수신 케이스를 어떤 축으로 검증해야 하는지 한 표로 고정한다.
- 운영자는 이 매트릭스를 기준으로 evidence template을 채우고, `#482` 종료 증거를 남긴다.

## 선행 문서
- rollout evidence runbook: `docs/auth-smtp-rollout-evidence-runbook-v1.md`
- copy-ready evidence template: `docs/auth-smtp-rollout-evidence-template-v1.md`
- closure checklist: `docs/auth-smtp-closure-checklist-v1.md`
- provider / DNS / secret checklist: `docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md`

## 검증 축
- `accepted`
  - Supabase/Auth/provider 단계에서 발송 accepted 확인
- `mailbox_received`
  - 실제 수신함 도착 확인
- `redirect_valid`
  - 메일 링크가 기대한 앱/웹 진입 경로로 이동
- `provider_event_checked`
  - provider dashboard 또는 webhook에서 downstream event 확인
- `request_id`
  - 가능하면 app/server/provider correlation key 확보
- `provider_message_id`
  - provider accepted 식별자 확보

## Positive Cases

| Case ID | Scenario | Recipient Type | accepted | mailbox_received | redirect_valid | provider_event_checked | request_id | provider_message_id | Required Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SMTP-001 | signup confirmation | 신규 이메일 | Y | Y | Y | Y | Optional | Y | provider verification, mailbox screenshot, accepted log |
| SMTP-002 | password reset | 기존 가입 이메일 | Y | Y | Y | Y | Optional | Y | reset mailbox screenshot, accepted log |
| SMTP-003 | email change | signed-in 사용자 | Y | Y | Y | Y | Optional | Y | change mail screenshot, accepted log |

## Negative / Guard Cases

| Case ID | Scenario | Expected Result | accepted | mailbox_received | provider_event_checked | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| SMTP-101 | duplicate resend under cooldown | duplicate suppressed or rate-limited | Optional | N | Optional | `retry_after_seconds` 또는 cooldown evidence |
| SMTP-102 | bounce target mailbox | provider bounce 확인 | Optional | N | Y | provider bounce screenshot or event id |
| SMTP-103 | reject or policy block | provider reject/deferred 확인 | Optional | N | Y | reason code and retry policy |

## 환경 구분

| Environment | Required | Notes |
| --- | --- | --- |
| local/dev | N | 개발 편의용. `#482` 종료 증거로 사용하지 않음 |
| staging | Recommended | production 전 dry run 근거 |
| production | Y | `#482` DoD를 만족하는 최종 증거 |

## 완료 판정
- production 기준으로 `SMTP-001`, `SMTP-002`, `SMTP-003`이 모두 `mailbox_received=Y`여야 한다.
- `SMTP-101` 또는 동등한 cooldown/rate-limit guard evidence가 하나 이상 있어야 한다.
- `SMTP-102` 또는 `SMTP-103` 중 최소 하나는 provider event 수준에서 확인돼야 한다.
- evidence template와 runbook 링크를 issue 또는 PR 코멘트에 남겨야 한다.

## 운영 규칙
- 이 매트릭스가 비어 있으면 `#482`를 닫지 않는다.
- provider 교체, sender domain 변경, hosted auth 설정 변경 시 다시 채운다.
