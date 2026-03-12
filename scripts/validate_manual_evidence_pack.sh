#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/auth_smtp_evidence_bundle.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/validate_manual_evidence_pack.sh <widget|auth-smtp> <path>

Examples:
  bash scripts/validate_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence
  bash scripts/validate_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence
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

extract_prefixed_value() {
  local prefix="$1"
  local file="$2"
  local line value

  line="$(line_by_prefix "$prefix" "$file")"
  [[ -n "$line" ]] || return 1
  value="${line#"$prefix"}"
  trim "$value"
}

require_existing_relative_asset() {
  local base_dir="$1"
  local relative_path="$2"
  local source_label="$3"
  local normalized

  normalized="$(trim "$relative_path")"
  if [[ -z "$normalized" ]]; then
    add_error "empty asset path: $source_label"
    return
  fi

  if [[ "$normalized" == "n/a" || "$normalized" == "N/A" ]]; then
    return
  fi

  if [[ "$normalized" = /* ]]; then
    add_error "asset path must be relative: $source_label :: $normalized"
    return
  fi

  if [[ ! -e "$base_dir/$normalized" ]]; then
    add_error "missing asset file: $source_label :: $normalized"
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
  local bundle_root="$3"
  local step1_path step2_path step_fail_path

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

  step1_path="$(extract_prefixed_value '- `step-1`:' "$file" || true)"
  step2_path="$(extract_prefixed_value '- `step-2`:' "$file" || true)"
  step_fail_path="$(extract_prefixed_value '- `step-fail`:' "$file" || true)"

  [[ -n "$step1_path" ]] && require_existing_relative_asset "$bundle_root" "$step1_path" "$file :: step-1"
  [[ -n "$step2_path" ]] && require_existing_relative_asset "$bundle_root" "$step2_path" "$file :: step-2"
  if [[ -n "$step_fail_path" && "$step_fail_path" != "n/a" && "$step_fail_path" != "N/A" ]]; then
    require_existing_relative_asset "$bundle_root" "$step_fail_path" "$file :: step-fail"
  fi

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
  local bundle_root="$3"
  local step1_path step2_path step_fail_path

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

  step1_path="$(extract_prefixed_value '- `step-1`:' "$file" || true)"
  step2_path="$(extract_prefixed_value '- `step-2`:' "$file" || true)"
  step_fail_path="$(extract_prefixed_value '- `step-fail`:' "$file" || true)"

  [[ -n "$step1_path" ]] && require_existing_relative_asset "$bundle_root" "$step1_path" "$file :: step-1"
  [[ -n "$step2_path" ]] && require_existing_relative_asset "$bundle_root" "$step2_path" "$file :: step-2"
  if [[ -n "$step_fail_path" && "$step_fail_path" != "n/a" && "$step_fail_path" != "N/A" ]]; then
    require_existing_relative_asset "$bundle_root" "$step_fail_path" "$file :: step-fail"
  fi

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
    validate_widget_action_case "$dir/action/${id}.md" "$id" "$dir"
  done

  for id in "${layout_ids[@]}"; do
    validate_widget_layout_case "$dir/layout/${id}.md" "$id" "$dir"
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
      for (i = 3; i <= 10; i++) {
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

auth_row_cell() {
  local scenario="$1"
  local file="$2"
  local column="$3"

  awk -F'|' -v scenario="$scenario" -v column="$column" '
    {
      first = $2
      gsub(/^[ \t]+|[ \t]+$/, "", first)
      if (first == scenario) {
        value = $column
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

validate_auth_smtp_bundle() {
  local dir="$1"
  local dns_path settings_path live_send_path negative_path ops_path decision_path
  local dns_asset settings_asset negative_asset live_signup_asset live_reset_asset live_change_asset

  [[ -d "$dir" ]] || {
    add_error "auth-smtp evidence must be a directory: $dir"
    return
  }

  dns_path="$(auth_smtp_bundle_dns_path "$dir")"
  settings_path="$(auth_smtp_bundle_settings_path "$dir")"
  live_send_path="$(auth_smtp_bundle_live_send_path "$dir")"
  negative_path="$(auth_smtp_bundle_negative_path "$dir")"
  ops_path="$(auth_smtp_bundle_ops_path "$dir")"
  decision_path="$(auth_smtp_bundle_decision_path "$dir")"

  [[ -f "$dns_path" ]] || add_error "missing file: $dns_path"
  [[ -f "$settings_path" ]] || add_error "missing file: $settings_path"
  [[ -f "$live_send_path" ]] || add_error "missing file: $live_send_path"
  [[ -f "$negative_path" ]] || add_error "missing file: $negative_path"
  [[ -f "$ops_path" ]] || add_error "missing file: $ops_path"
  [[ -f "$decision_path" ]] || add_error "missing file: $decision_path"

  if [[ -f "$dns_path" ]]; then
    require_nonempty_prefixed_line "- Date:" "$dns_path"
    require_nonempty_prefixed_line "- Operator:" "$dns_path"
    require_nonempty_prefixed_line "- Supabase Project:" "$dns_path"
    require_nonempty_prefixed_line "- Provider:" "$dns_path"
    require_nonempty_prefixed_line "- Sender Domain:" "$dns_path"
    require_nonempty_prefixed_line "- SPF:" "$dns_path"
    require_nonempty_prefixed_line "- DKIM:" "$dns_path"
    require_nonempty_prefixed_line "- DMARC:" "$dns_path"
    require_nonempty_prefixed_line "- Provider Verified Timestamp:" "$dns_path"
    require_nonempty_prefixed_line "- Evidence Screenshot:" "$dns_path"
    dns_asset="$(extract_prefixed_value "- Evidence Screenshot:" "$dns_path" || true)"
    [[ -n "$dns_asset" ]] && require_existing_relative_asset "$dir" "$dns_asset" "$dns_path :: Evidence Screenshot"
  fi

  if [[ -f "$settings_path" ]]; then
    require_nonempty_prefixed_line "- SMTP Host:" "$settings_path"
    require_nonempty_prefixed_line "- SMTP Port:" "$settings_path"
    require_nonempty_prefixed_line "- SMTP User Mask:" "$settings_path"
    require_nonempty_prefixed_line "- Sender Name:" "$settings_path"
    require_nonempty_prefixed_line "- Sender Email:" "$settings_path"
    require_nonempty_prefixed_line '- `email_sent`:' "$settings_path"
    require_nonempty_prefixed_line '- `auth.email.max_frequency`:' "$settings_path"
    require_nonempty_prefixed_line "- Email Confirmation Policy:" "$settings_path"
    require_nonempty_prefixed_line "- Password Reset Policy:" "$settings_path"
    require_nonempty_prefixed_line "- Email Change Policy:" "$settings_path"
    require_nonempty_prefixed_line "- Invite Policy:" "$settings_path"
    require_nonempty_prefixed_line "- Settings Screenshot:" "$settings_path"
    settings_asset="$(extract_prefixed_value "- Settings Screenshot:" "$settings_path" || true)"
    [[ -n "$settings_asset" ]] && require_existing_relative_asset "$dir" "$settings_asset" "$settings_path :: Settings Screenshot"
  fi

  if [[ -f "$live_send_path" ]]; then
    require_auth_row_filled "signup confirmation" "$live_send_path"
    require_auth_row_filled "password reset" "$live_send_path"
    require_auth_row_filled "email change" "$live_send_path"

    live_signup_asset="$(auth_row_cell "signup confirmation" "$live_send_path" 9)"
    live_reset_asset="$(auth_row_cell "password reset" "$live_send_path" 9)"
    live_change_asset="$(auth_row_cell "email change" "$live_send_path" 9)"

    [[ -n "$live_signup_asset" ]] && require_existing_relative_asset "$dir" "$live_signup_asset" "$live_send_path :: signup confirmation evidence_asset"
    [[ -n "$live_reset_asset" ]] && require_existing_relative_asset "$dir" "$live_reset_asset" "$live_send_path :: password reset evidence_asset"
    [[ -n "$live_change_asset" ]] && require_existing_relative_asset "$dir" "$live_change_asset" "$live_send_path :: email change evidence_asset"
  fi

  if [[ -f "$negative_path" ]]; then
    require_nonempty_prefixed_line "- SMTP-101 Guard Evidence:" "$negative_path"
    require_nonempty_prefixed_line "- SMTP-102 Provider Event Evidence:" "$negative_path"
    require_nonempty_prefixed_line "- bounce:" "$negative_path"
    require_nonempty_prefixed_line "- reject:" "$negative_path"
    require_nonempty_prefixed_line "- deferred:" "$negative_path"
    require_nonempty_prefixed_line "- provider_event_id:" "$negative_path"
    require_nonempty_prefixed_line "- Dashboard / Webhook Evidence:" "$negative_path"
    negative_asset="$(extract_prefixed_value "- Dashboard / Webhook Evidence:" "$negative_path" || true)"
    [[ -n "$negative_asset" ]] && require_existing_relative_asset "$dir" "$negative_asset" "$negative_path :: Dashboard / Webhook Evidence"
  fi

  if [[ -f "$ops_path" ]]; then
    require_nonempty_prefixed_line "- rollback path:" "$ops_path"
    require_nonempty_prefixed_line "- secret rotation owner:" "$ops_path"
    require_nonempty_prefixed_line "- tested backup path:" "$ops_path"
  fi

  if [[ -f "$decision_path" ]]; then
    require_nonempty_prefixed_line "- Pass / Fail:" "$decision_path"
    require_nonempty_prefixed_line "- Remaining Blockers:" "$decision_path"
    require_nonempty_prefixed_line "- Linked Issue / PR Comment:" "$decision_path"
    require_pass_outcome "$decision_path"
  fi
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
    validate_auth_smtp_bundle "$path"
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
