# Auth SMTP Rollout Evidence Template v1

- Issue: #664
- Relates to: #482

## canonical bundle layout
- `assets/`
- `01-dns-verification.md`
- `02-supabase-smtp-settings.md`
- `03-live-send-results.md`
- `04-negative-evidence.md`
- `05-rollback-rotation.md`
- `06-final-decision.md`

## 01-dns-verification.md
```md
# DNS Verification

- Date:
- Operator:
- Supabase Project:
- Provider:
- Sender Domain:
- SPF:
- DKIM:
- DMARC:
- Provider Verified Timestamp:
- Evidence Screenshot: assets/provider-domain.png
```

## 02-supabase-smtp-settings.md
```md
# Supabase Auth SMTP Settings

- SMTP Host:
- SMTP Port:
- SMTP User Mask:
- Sender Name:
- Sender Email:
- `email_sent`:
- `auth.email.max_frequency`:
- Email Confirmation Policy:
- Password Reset Policy:
- Email Change Policy:
- Invite Policy:
- Settings Screenshot: assets/supabase-smtp-settings.png
```

## 03-live-send-results.md
```md
# Live Send Results

| Scenario | Recipient Mask | Request Time | Accepted | Mailbox Received | request_id | provider_message_id | evidence_asset | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| signup confirmation |  |  |  |  |  |  | assets/signup-mailbox.png |  |
| password reset |  |  |  |  |  |  | assets/password-reset-mailbox.png |  |
| email change |  |  |  |  |  |  | assets/email-change-mailbox.png |  |
```

## 04-negative-evidence.md
```md
# Negative / Provider Event Evidence

- SMTP-101 Guard Evidence:
- SMTP-102 Provider Event Evidence:
- bounce:
- reject:
- deferred:
- provider_event_id:
- Dashboard / Webhook Evidence: assets/provider-dashboard-event.png
```

## 05-rollback-rotation.md
```md
# Rollback / Rotation Readiness

- rollback path:
- secret rotation owner:
- tested backup path:
- notes:
```

## 06-final-decision.md
```md
# Final Decision

- Pass / Fail:
- Remaining Blockers:
- Linked Issue / PR Comment:
```
