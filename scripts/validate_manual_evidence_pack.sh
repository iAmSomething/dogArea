#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/validate_manual_evidence_pack.sh <widget|auth-smtp> <path>

Examples:
  bash scripts/validate_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence
  bash scripts/validate_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence-pack.md
USAGE
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
    add_error "missing line: $file :: $prefix"
    return
  fi

  value="${line#"$prefix"}"
  value="$(trim "$value")"
  if [[ -z "$value" ]]; then
    add_error "empty value: $file :: $prefix"
  fi
}

require_contains() {
  local literal="$1"
  local file="$2"
  if ! grep -Fq "$literal" "$file"; then
    add_error "missing content: $file :: $literal"
  fi
}

require_absent_literal() {
  local literal="$1"
  local file="$2"
  if grep -Fqx "$literal" "$file"; then
    add_error "placeholder literal remains: $file :: $literal"
  fi
}

require_pass_outcome() {
  local file="$1"
  local line value
  line="$(line_by_prefix "- Pass / Fail:" "$file")"
  [[ -n "$line" ]] || return
  value="$(trim "${line#"- Pass / Fail:"}")"
  if [[ "$value" != "Pass" && "$value" != "PASS" ]]; then
    add_error "non-pass outcome: $file :: $value"
  fi
}

validate_widget_action_case() {
  local file="$1"
  local expected_case="$2"

  [[ -f "$file" ]] || {
    add_error "missing action file: $file"
    return
  }

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
  require_nonempty_prefixed_line '- `step-1`:' "$file"
  require_nonempty_prefixed_line '- `step-2`:' "$file"
  require_pass_outcome "$file"

  require_contains "[WidgetAction]" "$file"
  require_contains "onOpenURL received" "$file"
  require_contains "consumePendingWidgetActionIfNeeded" "$file"
  require_contains "request_id=" "$file"

  require_absent_literal "[WidgetAction] ..." "$file"
  require_absent_literal "onOpenURL received: ..." "$file"
  require_absent_literal "consumePendingWidgetActionIfNeeded ..." "$file"
  require_absent_literal "request_id=..." "$file"

  if ! grep -Fq -- "- Case ID: ${expected_case}" "$file"; then
    add_error "unexpected action case id: $file :: expected ${expected_case}"
  fi
}

validate_widget_layout_case() {
  local file="$1"
  local expected_case="$2"

  [[ -f "$file" ]] || {
    add_error "missing layout file: $file"
    return
  }

  require_nonempty_prefixed_line "- Date:" "$file"
  require_nonempty_prefixed_line "- Tester:" "$file"
  require_nonempty_prefixed_line "- Device / OS:" "$file"
  require_nonempty_prefixed_line "- App Build:" "$file"
  require_nonempty_prefixed_line "- Widget Surface:" "$file"
  require_nonempty_prefixed_line "- Widget Family:" "$file"
  require_nonempty_prefixed_line "- Case ID:" "$file"
  require_nonempty_prefixed_line "- Covered States:" "$file"
  require_nonempty_prefixed_line "- Headline Policy:" "$file"
  require_nonempty_prefixed_line "- Detail Policy:" "$file"
  require_nonempty_prefixed_line "- Badge Budget:" "$file"
  require_nonempty_prefixed_line "- CTA Height Rule:" "$file"
  require_nonempty_prefixed_line "- Metric Tile Rule:" "$file"
  require_nonempty_prefixed_line "- Compact Formatting Rule:" "$file"
  require_nonempty_prefixed_line "- Expected Result:" "$file"
  require_nonempty_prefixed_line "- Summary:" "$file"
  require_nonempty_prefixed_line "- Pass / Fail:" "$file"
  require_nonempty_prefixed_line '- `step-1`:' "$file"
  require_nonempty_prefixed_line '- `step-2`:' "$file"
  require_pass_outcome "$file"

  if ! grep -Fq -- "- Case ID: ${expected_case}" "$file"; then
    add_error "unexpected layout case id: $file :: expected ${expected_case}"
  fi
}

validate_widget_bundle() {
  local dir="$1"
  local action_ids=(WD-001 WD-002 WD-003 WD-004 WD-005 WD-006 WD-007 WD-008)
  local layout_ids=(WL-001 WL-002 WL-003 WL-004 WL-005 WL-006 WL-007 WL-008)
  local id

  [[ -d "$dir" ]] || {
    add_error "widget evidence must be a directory: $dir"
    return
  }

  for id in "${action_ids[@]}"; do
    validate_widget_action_case "$dir/action/${id}.md" "$id"
  done

  for id in "${layout_ids[@]}"; do
    validate_widget_layout_case "$dir/layout/${id}.md" "$id"
  done
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

  awk -F'|' -v row="$row" '
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
  require_nonempty_prefixed_line '- `email_sent`:' "$file"
  require_nonempty_prefixed_line '- `auth.email.max_frequency`:' "$file"
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

[[ -e "$path" ]] || {
  printf 'validate_manual_evidence_pack.sh: missing path: %s\n' "$path" >&2
  exit 1
}

case "$kind" in
  widget)
    validate_widget_bundle "$path"
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
