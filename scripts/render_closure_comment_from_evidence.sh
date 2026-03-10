#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/render_closure_comment_from_evidence.sh widget <evidence-dir-or-file> [--write] [--output <path>]
  bash scripts/render_closure_comment_from_evidence.sh auth-smtp <evidence-file> --negative-guard <text> --negative-provider-event <text> [--write] [--output <path>]
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

extract_prefixed_value() {
  local prefix="$1"
  local file="$2"
  local line value
  line="$(line_by_prefix "$prefix" "$file")"
  [[ -n "$line" ]] || {
    printf 'render_closure_comment_from_evidence.sh: missing line %s in %s\n' "$prefix" "$file" >&2
    exit 1
  }
  value="${line#"$prefix"}"
  trim "$value"
}

collect_row_message() {
  local scenario="$1"
  local file="$2"
  awk -F'|' -v scenario="$scenario" '
    {
      first = $2
      gsub(/^[ \t]+|[ \t]+$/, "", first)
      if (first == scenario) {
        recipientMask = $3
        acceptedState = $5
        receivedState = $6
        providerMessageID = $8
        gsub(/^[ \t]+|[ \t]+$/, "", recipientMask)
        gsub(/^[ \t]+|[ \t]+$/, "", acceptedState)
        gsub(/^[ \t]+|[ \t]+$/, "", receivedState)
        gsub(/^[ \t]+|[ \t]+$/, "", providerMessageID)
        printf "recipient=%s, accepted=%s, mailbox=%s, provider_message_id=%s", recipientMask, acceptedState, receivedState, providerMessageID
        exit
      }
    }
  ' "$file"
}

kind="${1:-}"
input_path="${2:-}"
shift $(( $# >= 2 ? 2 : $# ))

[[ -n "$kind" && -n "$input_path" ]] || {
  usage
  exit 1
}

negative_guard=""
negative_provider_event=""
write_mode=0
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --negative-guard)
      negative_guard="${2:-}"
      shift 2
      ;;
    --negative-provider-event)
      negative_provider_event="${2:-}"
      shift 2
      ;;
    --write)
      write_mode=1
      shift
      ;;
    --output|-o)
      output_path="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'render_closure_comment_from_evidence.sh: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

case "$kind" in
  widget)
    default_output_path=".codex_tmp/widget-action-closure-comment.md"
    ;;
  auth-smtp)
    default_output_path=".codex_tmp/auth-smtp-closure-comment.md"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [[ -z "$output_path" && "$write_mode" == "1" ]]; then
  output_path="$default_output_path"
fi

render_widget_comment() {
  local path="$1"
  local -a files
  local -a expected_ids=(WD-001 WD-002 WD-003 WD-004 WD-005 WD-006 WD-007 WD-008)
  local summary_map_file
  summary_map_file="$(mktemp)"
  trap 'rm -f "$summary_map_file"' RETURN

  if [[ -d "$path" ]]; then
    while IFS= read -r file; do
      files+=("$file")
    done < <(find "$path" -maxdepth 1 -type f -name '*.md' | sort)
  else
    files=("$path")
  fi

  [[ "${#files[@]}" -gt 0 ]] || {
    printf 'render_closure_comment_from_evidence.sh: no widget evidence files found\n' >&2
    exit 1
  }

  for file in "${files[@]}"; do
    bash scripts/validate_manual_evidence_pack.sh widget "$file" >/dev/null || return 1
    local case_id summary pass_fail
    case_id="$(extract_prefixed_value "- Case ID:" "$file")"
    summary="$(extract_prefixed_value "- Summary:" "$file")"
    pass_fail="$(extract_prefixed_value "- Pass / Fail:" "$file")"
    if [[ "$pass_fail" != "Pass" && "$pass_fail" != "PASS" ]]; then
      printf 'render_closure_comment_from_evidence.sh: widget case %s is not passing\n' "$case_id" >&2
      exit 1
    fi
    printf '%s\t%s\n' "$case_id" "Pass - $summary" >> "$summary_map_file"
  done

  for case_id in "${expected_ids[@]}"; do
    if ! awk -F'\t' -v case_id="$case_id" '$1 == case_id { found = 1 } END { exit(found ? 0 : 1) }' "$summary_map_file"; then
      printf 'render_closure_comment_from_evidence.sh: missing widget case %s\n' "$case_id" >&2
      exit 1
    fi
  done

  summary_for_case() {
    local case_id="$1"
    awk -F'\t' -v case_id="$case_id" '$1 == case_id { print $2; exit }' "$summary_map_file"
  }

  cat <<EOF
실기기 위젯 액션 검증을 완료했습니다.

검증 기준 문서
- \`docs/widget-action-real-device-validation-matrix-v1.md\`
- \`docs/widget-action-real-device-evidence-runbook-v1.md\`
- \`docs/widget-action-closure-checklist-v1.md\`

완료 케이스
- \`WD-001\`: $(summary_for_case WD-001)
- \`WD-002\`: $(summary_for_case WD-002)
- \`WD-003\`: $(summary_for_case WD-003)
- \`WD-004\`: $(summary_for_case WD-004)
- \`WD-005\`: $(summary_for_case WD-005)
- \`WD-006\`: $(summary_for_case WD-006)
- \`WD-007\`: $(summary_for_case WD-007)
- \`WD-008\`: $(summary_for_case WD-008)

공통 로그 확인
- \`WidgetAction\`
- \`onOpenURL received\`
- \`consumePendingWidgetActionIfNeeded\`

남은 blocker
- 없음

결론
- \`#408\` DoD를 충족했으므로 종료합니다.
EOF
}

render_auth_comment() {
  local file="$1"
  [[ -n "$negative_guard" ]] || {
    printf 'render_closure_comment_from_evidence.sh: --negative-guard is required for auth-smtp\n' >&2
    exit 1
  }
  [[ -n "$negative_provider_event" ]] || {
    printf 'render_closure_comment_from_evidence.sh: --negative-provider-event is required for auth-smtp\n' >&2
    exit 1
  }

  bash scripts/validate_manual_evidence_pack.sh auth-smtp "$file" >/dev/null || return 1

  local provider sender project spf dkim dmarc
  provider="$(extract_prefixed_value "- Provider:" "$file")"
  sender="$(extract_prefixed_value "- Sender Domain:" "$file")"
  project="$(extract_prefixed_value "- Supabase Project:" "$file")"
  spf="$(extract_prefixed_value "- SPF:" "$file")"
  dkim="$(extract_prefixed_value "- DKIM:" "$file")"
  dmarc="$(extract_prefixed_value "- DMARC:" "$file")"

  local signup_summary reset_summary change_summary
  signup_summary="$(collect_row_message "signup confirmation" "$file")"
  reset_summary="$(collect_row_message "password reset" "$file")"
  change_summary="$(collect_row_message "email change" "$file")"

  cat <<EOF
custom SMTP rollout 운영 증적을 확인했습니다.

검증 기준 문서
- \`docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md\`
- \`docs/auth-smtp-rollout-evidence-runbook-v1.md\`
- \`docs/auth-smtp-live-send-validation-matrix-v1.md\`
- \`docs/auth-smtp-closure-checklist-v1.md\`

provider / sender
- Provider: $provider
- Sender Domain: $sender
- Supabase Project: $project

DNS verification
- SPF: $spf
- DKIM: $dkim
- DMARC: $dmarc

Positive cases
- \`SMTP-001\`: $signup_summary
- \`SMTP-002\`: $reset_summary
- \`SMTP-003\`: $change_summary

Negative / guard evidence
- \`SMTP-101\`: $negative_guard
- \`SMTP-102\` or \`SMTP-103\`: $negative_provider_event

Rollback / rotation
- rollback path: $(extract_prefixed_value "- rollback path:" "$file")
- secret rotation owner: $(extract_prefixed_value "- secret rotation owner:" "$file")

남은 blocker
- 없음

결론
- \`#482\` DoD를 충족했으므로 종료합니다.
EOF
}

if [[ "$kind" == "widget" ]]; then
  rendered="$(render_widget_comment "$input_path")"
else
  rendered="$(render_auth_comment "$input_path")"
fi

if [[ -n "$output_path" ]]; then
  mkdir -p "$(dirname "$output_path")"
  printf '%s\n' "$rendered" > "$output_path"
  printf 'WROTE %s\n' "$output_path"
else
  printf '%s\n' "$rendered"
fi
