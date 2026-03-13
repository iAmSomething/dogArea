#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/auth_smtp_evidence_bundle.sh"
source "$ROOT_DIR/scripts/lib/manual_evidence_prefill_sources.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/prefill_manual_evidence_pack.sh <widget|auth-smtp> <path>

Examples:
  bash scripts/prefill_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence
  bash scripts/prefill_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence
USAGE
}

die() {
  printf 'prefill_manual_evidence_pack.sh: %s\n' "$*" >&2
  exit 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

fill_prefixed_value_if_empty() {
  local file="$1"
  local prefix="$2"
  local replacement="$3"
  local normalized

  [[ -f "$file" ]] || return
  normalized="$(trim "$replacement")"
  [[ -n "$normalized" ]] || return

  local tmp_file
  tmp_file="$(mktemp)"
  awk -v prefix="$prefix" -v replacement="$normalized" '
    function trim_value(value) {
      gsub(/^[ \t]+|[ \t]+$/, "", value)
      return value
    }
    index($0, prefix) == 1 {
      value = substr($0, length(prefix) + 1)
      if (trim_value(value) == "") {
        print prefix " " replacement
        next
      }
    }
    { print }
  ' "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
}

prefill_widget_bundle() {
  local dir="$1"
  local file

  [[ -d "$dir" ]] || die "widget evidence path must be a directory: $dir"

  for file in "$dir"/action/*.md "$dir"/layout/*.md; do
    [[ -f "$file" ]] || continue
    fill_prefixed_value_if_empty "$file" "- Date:" "$(widget_prefill_date)"
    fill_prefixed_value_if_empty "$file" "- Tester:" "$(widget_prefill_tester)"
    fill_prefixed_value_if_empty "$file" "- Device / OS:" "$(widget_prefill_device_os)"
    fill_prefixed_value_if_empty "$file" "- App Build:" "$(widget_prefill_app_build)"
  done
}

prefill_auth_smtp_bundle() {
  local dir="$1"
  [[ -d "$dir" ]] || die "auth-smtp evidence path must be a directory: $dir"

  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- Date:" "${DOGAREA_AUTH_SMTP_DATE:-$(date '+%F')}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- Operator:" "${DOGAREA_AUTH_SMTP_OPERATOR:-${USER:-}}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- Supabase Project:" "${DOGAREA_AUTH_SMTP_PROJECT:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- Provider:" "${DOGAREA_AUTH_SMTP_PROVIDER:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- Sender Domain:" "${DOGAREA_AUTH_SMTP_SENDER_DOMAIN:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- SPF:" "${DOGAREA_AUTH_SMTP_DNS_SPF:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- DKIM:" "${DOGAREA_AUTH_SMTP_DNS_DKIM:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- DMARC:" "${DOGAREA_AUTH_SMTP_DNS_DMARC:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_dns_path "$dir")" "- Provider Verified Timestamp:" "${DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT:-}"

  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- SMTP Host:" "${DOGAREA_AUTH_SMTP_HOST:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- SMTP Port:" "${DOGAREA_AUTH_SMTP_PORT:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- SMTP User Mask:" "${DOGAREA_AUTH_SMTP_USER_MASK:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- Sender Name:" "${DOGAREA_AUTH_SMTP_SENDER_NAME:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- Sender Email:" "${DOGAREA_AUTH_SMTP_SENDER_EMAIL:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" '- `email_sent`:' "${DOGAREA_AUTH_SMTP_EMAIL_SENT:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" '- `auth.email.max_frequency`:' "${DOGAREA_AUTH_SMTP_MAX_FREQUENCY:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- Email Confirmation Policy:" "${DOGAREA_AUTH_SMTP_CONFIRM_EMAIL_POLICY:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- Password Reset Policy:" "${DOGAREA_AUTH_SMTP_PASSWORD_RESET_POLICY:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- Email Change Policy:" "${DOGAREA_AUTH_SMTP_EMAIL_CHANGE_POLICY:-}"
  fill_prefixed_value_if_empty "$(auth_smtp_bundle_settings_path "$dir")" "- Invite Policy:" "${DOGAREA_AUTH_SMTP_INVITE_POLICY:-}"
}

kind="${1:-}"
path="${2:-}"

if [[ -z "$kind" || -z "$path" ]]; then
  usage
  exit 1
fi

case "$kind" in
  widget)
    prefill_widget_bundle "$path"
    ;;
  auth-smtp)
    prefill_auth_smtp_bundle "$path"
    ;;
  *)
    usage
    exit 1
    ;;
esac

printf 'PREFILLED %s %s\n' "$kind" "$path"
