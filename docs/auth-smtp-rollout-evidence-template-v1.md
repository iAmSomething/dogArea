# Auth SMTP Rollout Evidence Template v1

- Issue: #664
- Relates to: #482

## 기록 메타
- Date:
- Operator:
- Supabase Project:
- Provider:
- Sender Domain:

## DNS Verification
- SPF:
- DKIM:
- DMARC:
- Provider Verified Timestamp:
- Evidence Screenshot:

## Supabase Auth SMTP Settings
- SMTP Host:
- SMTP Port:
- SMTP User Mask:
- Sender Name:
- Sender Email:
- `email_sent`:
- `auth.email.max_frequency`:
- Settings Screenshot:

## Mail Scenario Results
| Scenario | Recipient Mask | Request Time | Accepted | Mailbox Received | request_id | provider_message_id | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| signup confirmation |  |  |  |  |  |  |  |
| password reset |  |  |  |  |  |  |  |
| email change |  |  |  |  |  |  |  |

## Provider Event Evidence
- bounce:
- reject:
- deferred:
- provider_event_id:
- Dashboard / Webhook Evidence:

## Rollback / Rotation Readiness
- rollback path:
- secret rotation owner:
- tested backup path:
- notes:

## Final Decision
- Pass / Fail:
- Remaining Blockers:
- Linked Issue / PR Comment:
