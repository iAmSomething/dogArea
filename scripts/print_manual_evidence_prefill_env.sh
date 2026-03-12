#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/print_manual_evidence_prefill_env.sh <widget|auth-smtp>
USAGE
}

quote_value() {
  local value="$1"
  printf '%q' "$value"
}

widget_value() {
  local key="$1"
  case "$key" in
    DOGAREA_WIDGET_EVIDENCE_DATE) printf '%s' "${DOGAREA_WIDGET_EVIDENCE_DATE:-$(date '+%F')}" ;;
    DOGAREA_WIDGET_EVIDENCE_TESTER) printf '%s' "${DOGAREA_WIDGET_EVIDENCE_TESTER:-${USER:-codex}}" ;;
    DOGAREA_WIDGET_EVIDENCE_DEVICE_OS) printf '%s' "${DOGAREA_WIDGET_EVIDENCE_DEVICE_OS:-iPhone 16 / iOS 18.5}" ;;
    DOGAREA_WIDGET_EVIDENCE_APP_BUILD) printf '%s' "${DOGAREA_WIDGET_EVIDENCE_APP_BUILD:-2026.03.12.1}" ;;
  esac
}

auth_value() {
  local key="$1"
  case "$key" in
    DOGAREA_AUTH_SMTP_DATE) printf '%s' "${DOGAREA_AUTH_SMTP_DATE:-$(date '+%F')}" ;;
    DOGAREA_AUTH_SMTP_OPERATOR) printf '%s' "${DOGAREA_AUTH_SMTP_OPERATOR:-${USER:-codex}}" ;;
    DOGAREA_AUTH_SMTP_PROJECT) printf '%s' "${DOGAREA_AUTH_SMTP_PROJECT:-ttjiknenynbhbpoqoesq}" ;;
    DOGAREA_AUTH_SMTP_PROVIDER) printf '%s' "${DOGAREA_AUTH_SMTP_PROVIDER:-Resend}" ;;
    DOGAREA_AUTH_SMTP_SENDER_DOMAIN) printf '%s' "${DOGAREA_AUTH_SMTP_SENDER_DOMAIN:-auth.dogarea.app}" ;;
    DOGAREA_AUTH_SMTP_DNS_SPF) printf '%s' "${DOGAREA_AUTH_SMTP_DNS_SPF:-pass}" ;;
    DOGAREA_AUTH_SMTP_DNS_DKIM) printf '%s' "${DOGAREA_AUTH_SMTP_DNS_DKIM:-verified}" ;;
    DOGAREA_AUTH_SMTP_DNS_DMARC) printf '%s' "${DOGAREA_AUTH_SMTP_DNS_DMARC:-present}" ;;
    DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT) printf '%s' "${DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT:-2026-03-12T08:00:00Z}" ;;
    DOGAREA_AUTH_SMTP_HOST) printf '%s' "${DOGAREA_AUTH_SMTP_HOST:-smtp.resend.com}" ;;
    DOGAREA_AUTH_SMTP_PORT) printf '%s' "${DOGAREA_AUTH_SMTP_PORT:-587}" ;;
    DOGAREA_AUTH_SMTP_USER_MASK) printf '%s' "${DOGAREA_AUTH_SMTP_USER_MASK:-re_***}" ;;
    DOGAREA_AUTH_SMTP_SENDER_NAME) printf '%s' "${DOGAREA_AUTH_SMTP_SENDER_NAME:-DogArea Auth}" ;;
    DOGAREA_AUTH_SMTP_SENDER_EMAIL) printf '%s' "${DOGAREA_AUTH_SMTP_SENDER_EMAIL:-auth@auth.dogarea.app}" ;;
    DOGAREA_AUTH_SMTP_EMAIL_SENT) printf '%s' "${DOGAREA_AUTH_SMTP_EMAIL_SENT:-12}" ;;
    DOGAREA_AUTH_SMTP_MAX_FREQUENCY) printf '%s' "${DOGAREA_AUTH_SMTP_MAX_FREQUENCY:-90}" ;;
    DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY) printf '%s' "${DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY:-required}" ;;
    DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY) printf '%s' "${DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY:-enabled / app deep link}" ;;
    DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY) printf '%s' "${DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY:-double confirmation}" ;;
    DOGAREA_AUTH_SMTP_INVITE_POLICY) printf '%s' "${DOGAREA_AUTH_SMTP_INVITE_POLICY:-disabled in product}" ;;
  esac
}

print_widget_exports() {
  local keys=(
    DOGAREA_WIDGET_EVIDENCE_DATE
    DOGAREA_WIDGET_EVIDENCE_TESTER
    DOGAREA_WIDGET_EVIDENCE_DEVICE_OS
    DOGAREA_WIDGET_EVIDENCE_APP_BUILD
  )

  printf '# widget prefill env\n'
  for key in "${keys[@]}"; do
    printf 'export %s=%s\n' "$key" "$(quote_value "$(widget_value "$key")")"
  done
}

print_auth_exports() {
  local keys=(
    DOGAREA_AUTH_SMTP_DATE
    DOGAREA_AUTH_SMTP_OPERATOR
    DOGAREA_AUTH_SMTP_PROJECT
    DOGAREA_AUTH_SMTP_PROVIDER
    DOGAREA_AUTH_SMTP_SENDER_DOMAIN
    DOGAREA_AUTH_SMTP_DNS_SPF
    DOGAREA_AUTH_SMTP_DNS_DKIM
    DOGAREA_AUTH_SMTP_DNS_DMARC
    DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT
    DOGAREA_AUTH_SMTP_HOST
    DOGAREA_AUTH_SMTP_PORT
    DOGAREA_AUTH_SMTP_USER_MASK
    DOGAREA_AUTH_SMTP_SENDER_NAME
    DOGAREA_AUTH_SMTP_SENDER_EMAIL
    DOGAREA_AUTH_SMTP_EMAIL_SENT
    DOGAREA_AUTH_SMTP_MAX_FREQUENCY
    DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY
    DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY
    DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY
    DOGAREA_AUTH_SMTP_INVITE_POLICY
  )

  printf '# auth-smtp prefill env\n'
  for key in "${keys[@]}"; do
    printf 'export %s=%s\n' "$key" "$(quote_value "$(auth_value "$key")")"
  done
}

surface="${1:-}"
if [[ -z "$surface" ]]; then
  usage
  exit 1
fi

case "$surface" in
  widget)
    print_widget_exports
    ;;
  auth-smtp)
    print_auth_exports
    ;;
  *)
    usage
    exit 1
    ;;
esac
