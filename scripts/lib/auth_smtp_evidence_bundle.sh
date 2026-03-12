#!/usr/bin/env bash

if [[ -n "${DOGAREA_AUTH_SMTP_EVIDENCE_BUNDLE_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
DOGAREA_AUTH_SMTP_EVIDENCE_BUNDLE_LIB_LOADED=1

AUTH_SMTP_BUNDLE_DEFAULT_PATH=".codex_tmp/auth-smtp-evidence"

auth_smtp_bundle_default_path() {
  printf '%s' "${DOGAREA_AUTH_SMTP_EVIDENCE_PATH:-$AUTH_SMTP_BUNDLE_DEFAULT_PATH}"
}

auth_smtp_bundle_readme_path() {
  printf '%s/README.md' "$1"
}

auth_smtp_bundle_dns_path() {
  printf '%s/01-dns-verification.md' "$1"
}

auth_smtp_bundle_settings_path() {
  printf '%s/02-supabase-smtp-settings.md' "$1"
}

auth_smtp_bundle_live_send_path() {
  printf '%s/03-live-send-results.md' "$1"
}

auth_smtp_bundle_negative_path() {
  printf '%s/04-negative-evidence.md' "$1"
}

auth_smtp_bundle_ops_path() {
  printf '%s/05-rollback-rotation.md' "$1"
}

auth_smtp_bundle_decision_path() {
  printf '%s/06-final-decision.md' "$1"
}

auth_smtp_bundle_render_overview() {
  cat <<'EOF'
# Auth SMTP Evidence Bundle v2

- Related issue: #482
- Runbook: `docs/auth-smtp-rollout-evidence-runbook-v1.md`
- Validation matrix: `docs/auth-smtp-live-send-validation-matrix-v1.md`
- Closure checklist: `docs/auth-smtp-closure-checklist-v1.md`
- Bundle template: `docs/auth-smtp-rollout-evidence-template-v1.md`
- Closure comment template: `docs/auth-smtp-closure-comment-template-v1.md`
- Generated directory layout:
  - `README.md`
  - `01-dns-verification.md`
  - `02-supabase-smtp-settings.md`
  - `03-live-send-results.md`
  - `04-negative-evidence.md`
  - `05-rollback-rotation.md`
  - `06-final-decision.md`

Use `--write` or `--output <dir>` to materialize the bundle skeleton.
EOF
}

auth_smtp_bundle_write() {
  local dir="$1"
  mkdir -p "$dir"

  cat > "$(auth_smtp_bundle_readme_path "$dir")" <<'EOF'
# Auth SMTP Evidence Bundle v2

- Related issue: #482
- Runbook: `docs/auth-smtp-rollout-evidence-runbook-v1.md`
- Validation matrix: `docs/auth-smtp-live-send-validation-matrix-v1.md`
- Closure checklist: `docs/auth-smtp-closure-checklist-v1.md`
- Bundle template: `docs/auth-smtp-rollout-evidence-template-v1.md`
- Closure comment template: `docs/auth-smtp-closure-comment-template-v1.md`

## Files
- `01-dns-verification.md`
- `02-supabase-smtp-settings.md`
- `03-live-send-results.md`
- `04-negative-evidence.md`
- `05-rollback-rotation.md`
- `06-final-decision.md`
EOF

  cat > "$(auth_smtp_bundle_dns_path "$dir")" <<'EOF'
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
- Evidence Screenshot:
EOF

  cat > "$(auth_smtp_bundle_settings_path "$dir")" <<'EOF'
# Supabase Auth SMTP Settings

- SMTP Host:
- SMTP Port:
- SMTP User Mask:
- Sender Name:
- Sender Email:
- `email_sent`:
- `auth.email.max_frequency`:
- Settings Screenshot:
EOF

  cat > "$(auth_smtp_bundle_live_send_path "$dir")" <<'EOF'
# Live Send Results

| Scenario | Recipient Mask | Request Time | Accepted | Mailbox Received | request_id | provider_message_id | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| signup confirmation |  |  |  |  |  |  |  |
| password reset |  |  |  |  |  |  |  |
| email change |  |  |  |  |  |  |  |
EOF

  cat > "$(auth_smtp_bundle_negative_path "$dir")" <<'EOF'
# Negative / Provider Event Evidence

- SMTP-101 Guard Evidence:
- SMTP-102 Provider Event Evidence:
- bounce:
- reject:
- deferred:
- provider_event_id:
- Dashboard / Webhook Evidence:
EOF

  cat > "$(auth_smtp_bundle_ops_path "$dir")" <<'EOF'
# Rollback / Rotation Readiness

- rollback path:
- secret rotation owner:
- tested backup path:
- notes:
EOF

  cat > "$(auth_smtp_bundle_decision_path "$dir")" <<'EOF'
# Final Decision

- Pass / Fail:
- Remaining Blockers:
- Linked Issue / PR Comment:
EOF
}
