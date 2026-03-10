#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/validate_manual_evidence_pack.sh <widget|auth-smtp> <markdown-path>

Examples:
  bash scripts/validate_manual_evidence_pack.sh widget .codex_tmp/widget-action-evidence-pack.md
  bash scripts/validate_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence-pack.md
EOF
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

line_by_prefix() {
  local prefix="$1"
  local file="$2"
  awk -v prefix="$prefix" 'index($0, prefix) == 1 { print; exit }' "$file"
}

errors=()

add_error() {
  errors+=("$1")
}

require_nonempty_prefixed_line() {
  local prefix="$1"
  local file="$2"
  local line value

  line="$(line_by_prefix "$prefix" "$file")"
  if [[ -z "$line" ]]; then
    add_error "missing line: $prefix"
    return
  fi

  value="${line#"$prefix"}"
  value="$(trim "$value")"
  if [[ -z "$value" ]]; then
    add_error "empty value: $prefix"
  fi
}

require_absent_literal() {
  local literal="$1"
  local file="$2"
  if grep -Fqx "$literal" "$file"; then
    add_error "placeholder literal remains: $literal"
  fi
}

require_contains() {
  local literal="$1"
  local file="$2"
  if ! grep -Fq "$literal" "$file"; then
    add_error "missing content: $literal"
  fi
}

require_auth_row_filled() {
  local scenario="$1"
  local file="$2"
  local row

  row="$(awk -F'|' -v scenario="$scenario" '
    {
      first = $2
      gsub(/^[ \t]+|[ \t]+$/, "", first)
      if (first == scenario) {
        print $0
        exit
      }
    }
  ' "$file")"

  if [[ -z "$row" ]]; then
    add_error "missing scenario row: $scenario"
    return
  fi

  awk -F'|' -v row="$row" -v scenario="$scenario" '
    BEGIN {
      split(row, cells, "|")
      fail = 0
      for (i = 3; i <= 9; i++) {
        value = cells[i]
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        if (value == "") {
          fail = 1
        }
      }
      if (fail == 1) {
        exit 1
      }
    }
  ' || add_error "incomplete scenario row: $scenario"
}

validate_widget() {
  local file="$1"

  require_nonempty_prefixed_line "- Date:" "$file"
  require_nonempty_prefixed_line "- Tester:" "$file"
  require_nonempty_prefixed_line "- Device / OS:" "$file"
  require_nonempty_prefixed_line "- App Build:" "$file"
  require_nonempty_prefixed_line "- Widget Family:" "$file"
  require_nonempty_prefixed_line "- Case ID:" "$file"
  require_nonempty_prefixed_line "- 앱 상태:" "$file"
  require_nonempty_prefixed_line "- 인증 상태:" "$file"
  require_nonempty_prefixed_line "- Action Route:" "$file"
  require_nonempty_prefixed_line "- Expected Result:" "$file"
  require_nonempty_prefixed_line "- Summary:" "$file"
  require_nonempty_prefixed_line "- Final Screen:" "$file"
  require_nonempty_prefixed_line "- Pass / Fail:" "$file"
  require_nonempty_prefixed_line "- \`step-1\`:" "$file"
  require_nonempty_prefixed_line "- \`step-2\`:" "$file"

  require_contains "[WidgetAction]" "$file"
  require_contains "onOpenURL received" "$file"
  require_contains "consumePendingWidgetActionIfNeeded" "$file"
  require_contains "request_id=" "$file"

  require_absent_literal "[WidgetAction] ..." "$file"
  require_absent_literal "onOpenURL received: ..." "$file"
  require_absent_literal "consumePendingWidgetActionIfNeeded ..." "$file"
  require_absent_literal "request_id=..." "$file"
}

validate_auth_smtp() {
  local file="$1"

  require_nonempty_prefixed_line "- Date:" "$file"
  require_nonempty_prefixed_line "- Operator:" "$file"
  require_nonempty_prefixed_line "- Supabase Project:" "$file"
  require_nonempty_prefixed_line "- Provider:" "$file"
  require_nonempty_prefixed_line "- Sender Domain:" "$file"
  require_nonempty_prefixed_line "- SPF:" "$file"
  require_nonempty_prefixed_line "- DKIM:" "$file"
  require_nonempty_prefixed_line "- DMARC:" "$file"
  require_nonempty_prefixed_line "- Provider Verified Timestamp:" "$file"
  require_nonempty_prefixed_line "- Evidence Screenshot:" "$file"
  require_nonempty_prefixed_line "- SMTP Host:" "$file"
  require_nonempty_prefixed_line "- SMTP Port:" "$file"
  require_nonempty_prefixed_line "- SMTP User Mask:" "$file"
  require_nonempty_prefixed_line "- Sender Name:" "$file"
  require_nonempty_prefixed_line "- Sender Email:" "$file"
  require_nonempty_prefixed_line "- \`email_sent\`:" "$file"
  require_nonempty_prefixed_line "- \`auth.email.max_frequency\`:" "$file"
  require_nonempty_prefixed_line "- Settings Screenshot:" "$file"
  require_nonempty_prefixed_line "- bounce:" "$file"
  require_nonempty_prefixed_line "- reject:" "$file"
  require_nonempty_prefixed_line "- deferred:" "$file"
  require_nonempty_prefixed_line "- provider_event_id:" "$file"
  require_nonempty_prefixed_line "- Dashboard / Webhook Evidence:" "$file"
  require_nonempty_prefixed_line "- rollback path:" "$file"
  require_nonempty_prefixed_line "- secret rotation owner:" "$file"
  require_nonempty_prefixed_line "- tested backup path:" "$file"
  require_nonempty_prefixed_line "- Pass / Fail:" "$file"
  require_nonempty_prefixed_line "- Remaining Blockers:" "$file"
  require_nonempty_prefixed_line "- Linked Issue / PR Comment:" "$file"

  require_auth_row_filled "signup confirmation" "$file"
  require_auth_row_filled "password reset" "$file"
  require_auth_row_filled "email change" "$file"
}

kind="${1:-}"
path="${2:-}"

if [[ -z "$kind" || -z "$path" ]]; then
  usage
  exit 1
fi

[[ -f "$path" ]] || {
  printf 'validate_manual_evidence_pack.sh: missing file: %s\n' "$path" >&2
  exit 1
}

case "$kind" in
  widget)
    validate_widget "$path"
    ;;
  auth-smtp)
    validate_auth_smtp "$path"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [[ "${#errors[@]}" -gt 0 ]]; then
  printf 'FAIL: %s evidence is incomplete\n' "$kind" >&2
  for error in "${errors[@]}"; do
    printf ' - %s\n' "$error" >&2
  done
  exit 1
fi

printf 'PASS: %s evidence is complete\n' "$kind"
