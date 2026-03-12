#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/auth_smtp_evidence_bundle.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/auth_smtp_rollout_readiness_check.sh [--evidence <path>]

Environment inputs:
  DOGAREA_AUTH_SMTP_PROJECT
  DOGAREA_AUTH_SMTP_PROVIDER
  DOGAREA_AUTH_SMTP_SENDER_DOMAIN
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
  DOGAREA_AUTH_SMTP_DNS_SPF
  DOGAREA_AUTH_SMTP_DNS_DKIM
  DOGAREA_AUTH_SMTP_DNS_DMARC
USAGE
}

die() {
  printf 'auth_smtp_rollout_readiness_check.sh: %s\n' "$*" >&2
  exit 1
}

evidence_path="$(auth_smtp_bundle_default_path)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence)
      [[ $# -ge 2 ]] || die "--evidence requires a path"
      evidence_path="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

normalized_truthy() {
  local value="${1:-}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" == "1" || "$value" == "true" || "$value" == "yes" || "$value" == "pass" || "$value" == "verified" || "$value" == "present" || "$value" == "ready" || "$value" == "ok" ]]
}

join_by_comma() {
  local first=1
  local item
  for item in "$@"; do
    if [[ "$first" == "1" ]]; then
      printf '%s' "$item"
      first=0
    else
      printf ', %s' "$item"
    fi
  done
}

required_config_vars=(
  DOGAREA_AUTH_SMTP_PROJECT
  DOGAREA_AUTH_SMTP_PROVIDER
  DOGAREA_AUTH_SMTP_SENDER_DOMAIN
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

declare -a missing_config_vars=()
for var_name in "${required_config_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    missing_config_vars+=("$var_name")
  fi
done

declare -a missing_dns_claims=()
normalized_truthy "${DOGAREA_AUTH_SMTP_DNS_SPF:-}" || missing_dns_claims+=("DOGAREA_AUTH_SMTP_DNS_SPF")
normalized_truthy "${DOGAREA_AUTH_SMTP_DNS_DKIM:-}" || missing_dns_claims+=("DOGAREA_AUTH_SMTP_DNS_DKIM")
normalized_truthy "${DOGAREA_AUTH_SMTP_DNS_DMARC:-}" || missing_dns_claims+=("DOGAREA_AUTH_SMTP_DNS_DMARC")

config_status="ready"
[[ "${#missing_config_vars[@]}" -eq 0 ]] || config_status="missing"

dns_status="ready"
[[ "${#missing_dns_claims[@]}" -eq 0 ]] || dns_status="missing"

evidence_status="missing"
if [[ -e "$evidence_path" ]]; then
  if bash scripts/validate_manual_evidence_pack.sh auth-smtp "$evidence_path" >/tmp/dogarea_auth_smtp_preflight.$$ 2>&1; then
    evidence_status="complete"
  else
    evidence_status="incomplete"
  fi
  rm -f /tmp/dogarea_auth_smtp_preflight.$$
fi

overall_status="blocked:missing-config"
if [[ "$config_status" == "ready" && "$dns_status" == "ready" ]]; then
  case "$evidence_status" in
    complete) overall_status="ready-to-post" ;;
    incomplete|missing) overall_status="ready-for-live-send-evidence" ;;
  esac
elif [[ "$config_status" == "ready" && "$dns_status" != "ready" ]]; then
  overall_status="blocked:dns-unverified"
fi

printf 'title: auth smtp rollout readiness preflight\n'
printf 'issue: #482\n'
printf 'evidence-pack: %s\n' "$evidence_path"
printf 'config-inputs: %s\n' "$config_status"
if [[ "${#missing_config_vars[@]}" -gt 0 ]]; then
  printf 'missing-config-vars: %s\n' "$(join_by_comma "${missing_config_vars[@]}")"
else
  printf 'missing-config-vars: none\n'
fi
printf 'dns-claims: %s\n' "$dns_status"
if [[ "${#missing_dns_claims[@]}" -gt 0 ]]; then
  printf 'missing-dns-claims: %s\n' "$(join_by_comma "${missing_dns_claims[@]}")"
else
  printf 'missing-dns-claims: none\n'
fi
printf 'evidence-status: %s\n' "$evidence_status"
printf 'overall: %s\n' "$overall_status"
printf 'next-evidence-runbook: docs/auth-smtp-rollout-evidence-runbook-v1.md\n'
printf 'next-live-send-matrix: docs/auth-smtp-live-send-validation-matrix-v1.md\n'
printf 'next-render-prefilled: bash scripts/render_manual_evidence_pack.sh auth-smtp --output %q --prefill-from-env\n' "$evidence_path"
printf 'next-validate: bash scripts/validate_manual_evidence_pack.sh auth-smtp %q\n' "$evidence_path"
printf 'next-render-closure: bash scripts/render_closure_comment_from_evidence.sh auth-smtp %q --write\n' "$evidence_path"
printf 'next-post-closure: bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue 482 %q --post\n' "$evidence_path"
