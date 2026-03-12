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

auth_smtp_bundle_assets_dir() {
  printf '%s/assets' "$1"
}

auth_smtp_bundle_env_value() {
  local key="$1"
  printf '%s' "${!key:-}"
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
  - `assets/`
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
  mkdir -p "$dir" "$(auth_smtp_bundle_assets_dir "$dir")"

  cat > "$(auth_smtp_bundle_readme_path "$dir")" <<'EOF'
# Auth SMTP Evidence Bundle v2

- Related issue: #482
- Runbook: `docs/auth-smtp-rollout-evidence-runbook-v1.md`
- Validation matrix: `docs/auth-smtp-live-send-validation-matrix-v1.md`
- Closure checklist: `docs/auth-smtp-closure-checklist-v1.md`
- Bundle template: `docs/auth-smtp-rollout-evidence-template-v1.md`
- Closure comment template: `docs/auth-smtp-closure-comment-template-v1.md`

## Files
- `assets/`
- `01-dns-verification.md`
- `02-supabase-smtp-settings.md`
- `03-live-send-results.md`
- `04-negative-evidence.md`
- `05-rollback-rotation.md`
- `06-final-decision.md`
EOF

  cat > "$(auth_smtp_bundle_assets_dir "$dir")/README.md" <<'EOF'
# Auth SMTP Evidence Assets

- `provider-domain.png`
- `supabase-smtp-settings.png`
- `signup-mailbox.png`
- `password-reset-mailbox.png`
- `email-change-mailbox.png`
- `provider-dashboard-event.png`
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
- Evidence Screenshot: assets/provider-domain.png
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
- Email Confirmation Policy:
- Password Reset Policy:
- Email Change Policy:
- Invite Policy:
- Settings Screenshot: assets/supabase-smtp-settings.png
EOF

  cat > "$(auth_smtp_bundle_live_send_path "$dir")" <<'EOF'
# Live Send Results

| Scenario | Recipient Mask | Request Time | Accepted | Mailbox Received | request_id | provider_message_id | evidence_asset | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| signup confirmation |  |  |  |  |  |  | assets/signup-mailbox.png |  |
| password reset |  |  |  |  |  |  | assets/password-reset-mailbox.png |  |
| email change |  |  |  |  |  |  | assets/email-change-mailbox.png |  |
EOF

  cat > "$(auth_smtp_bundle_negative_path "$dir")" <<'EOF'
# Negative / Provider Event Evidence

- SMTP-101 Guard Evidence:
- SMTP-102 Provider Event Evidence:
- bounce:
- reject:
- deferred:
- provider_event_id:
- Dashboard / Webhook Evidence: assets/provider-dashboard-event.png
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

auth_smtp_bundle_write_prefilled() {
  local dir="$1"
  local date_value operator_value project provider sender_domain spf dkim dmarc verified_at
  local host port user_mask sender_name sender_email email_sent max_frequency
  local confirm_policy password_reset_policy email_change_policy invite_policy

  date_value="${DOGAREA_AUTH_SMTP_DATE:-$(date '+%F')}"
  operator_value="${DOGAREA_AUTH_SMTP_OPERATOR:-${USER:-}}"
  project="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_PROJECT)"
  provider="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_PROVIDER)"
  sender_domain="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_SENDER_DOMAIN)"
  spf="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_DNS_SPF)"
  dkim="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_DNS_DKIM)"
  dmarc="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_DNS_DMARC)"
  verified_at="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT)"
  host="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_HOST)"
  port="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_PORT)"
  user_mask="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_USER_MASK)"
  sender_name="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_SENDER_NAME)"
  sender_email="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_SENDER_EMAIL)"
  email_sent="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_EMAIL_SENT)"
  max_frequency="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_MAX_FREQUENCY)"
  confirm_policy="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY)"
  password_reset_policy="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY)"
  email_change_policy="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY)"
  invite_policy="$(auth_smtp_bundle_env_value DOGAREA_AUTH_SMTP_INVITE_POLICY)"

  mkdir -p "$dir" "$(auth_smtp_bundle_assets_dir "$dir")"

  cat > "$(auth_smtp_bundle_readme_path "$dir")" <<'EOF'
# Auth SMTP Evidence Bundle v2

- Related issue: #482
- Runbook: `docs/auth-smtp-rollout-evidence-runbook-v1.md`
- Validation matrix: `docs/auth-smtp-live-send-validation-matrix-v1.md`
- Closure checklist: `docs/auth-smtp-closure-checklist-v1.md`
- Closure comment template: `docs/auth-smtp-closure-comment-template-v1.md`

## Files
- `assets/`
- `01-dns-verification.md`
- `02-supabase-smtp-settings.md`
- `03-live-send-results.md`
- `04-negative-evidence.md`
- `05-rollback-rotation.md`
- `06-final-decision.md`
EOF

  cat > "$(auth_smtp_bundle_assets_dir "$dir")/README.md" <<'EOF'
# Auth SMTP Evidence Assets

- `provider-domain.png`
- `supabase-smtp-settings.png`
- `signup-mailbox.png`
- `password-reset-mailbox.png`
- `email-change-mailbox.png`
- `provider-dashboard-event.png`
EOF

  cat > "$(auth_smtp_bundle_dns_path "$dir")" <<EOF
# DNS Verification

- Date: ${date_value}
- Operator: ${operator_value}
- Supabase Project: ${project}
- Provider: ${provider}
- Sender Domain: ${sender_domain}
- SPF: ${spf}
- DKIM: ${dkim}
- DMARC: ${dmarc}
- Provider Verified Timestamp: ${verified_at}
- Evidence Screenshot: assets/provider-domain.png
EOF

  cat > "$(auth_smtp_bundle_settings_path "$dir")" <<EOF
# Supabase Auth SMTP Settings

- SMTP Host: ${host}
- SMTP Port: ${port}
- SMTP User Mask: ${user_mask}
- Sender Name: ${sender_name}
- Sender Email: ${sender_email}
- \`email_sent\`: ${email_sent}
- \`auth.email.max_frequency\`: ${max_frequency}
- Email Confirmation Policy: ${confirm_policy}
- Password Reset Policy: ${password_reset_policy}
- Email Change Policy: ${email_change_policy}
- Invite Policy: ${invite_policy}
- Settings Screenshot: assets/supabase-smtp-settings.png
EOF

  cat > "$(auth_smtp_bundle_live_send_path "$dir")" <<'EOF'
# Live Send Results

| Scenario | Recipient Mask | Request Time | Accepted | Mailbox Received | request_id | provider_message_id | evidence_asset | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| signup confirmation |  |  |  |  |  |  | assets/signup-mailbox.png |  |
| password reset |  |  |  |  |  |  | assets/password-reset-mailbox.png |  |
| email change |  |  |  |  |  |  | assets/email-change-mailbox.png |  |
EOF

  cat > "$(auth_smtp_bundle_negative_path "$dir")" <<'EOF'
# Negative / Provider Event Evidence

- SMTP-101 Guard Evidence:
- SMTP-102 Provider Event Evidence:
- bounce:
- reject:
- deferred:
- provider_event_id:
- Dashboard / Webhook Evidence: assets/provider-dashboard-event.png
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
