#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/auth_smtp_evidence_bundle.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/render_closure_comment_from_evidence.sh widget <evidence-dir> [--write] [--output <path>]
  bash scripts/render_closure_comment_from_evidence.sh auth-smtp <evidence-dir> [--write] [--output <path>]
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

write_mode=0
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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
  widget) default_output_path=".codex_tmp/widget-action-closure-comment.md" ;;
  auth-smtp) default_output_path=".codex_tmp/auth-smtp-closure-comment.md" ;;
  *) usage; exit 1 ;;
esac

if [[ -z "$output_path" && "$write_mode" == "1" ]]; then
  output_path="$default_output_path"
fi

render_widget_comment() {
  local dir="$1"
  local action_ids=(WD-001 WD-002 WD-003 WD-004 WD-005 WD-006 WD-007 WD-008)
  local layout_ids=(WL-001 WL-002 WL-003 WL-004 WL-005 WL-006 WL-007 WL-008)
  local id file summary

  [[ -d "$dir" ]] || {
    printf 'render_closure_comment_from_evidence.sh: widget evidence must be a directory\n' >&2
    exit 1
  }

  bash scripts/validate_manual_evidence_pack.sh widget "$dir" >/dev/null || return 1

  cat <<'HEADER'
실기기 위젯 blocker 검증을 완료했습니다.

검증 기준 문서
- `docs/widget-action-real-device-validation-matrix-v1.md`
- `docs/widget-family-real-device-validation-matrix-v1.md`
- `docs/widget-action-real-device-evidence-runbook-v1.md`
- `docs/widget-family-real-device-evidence-runbook-v1.md`
- `docs/widget-action-closure-checklist-v1.md`

액션 수렴 케이스
HEADER

  for id in "${action_ids[@]}"; do
    file="$dir/action/${id}.md"
    summary="$(extract_prefixed_value "- Summary:" "$file")"
    printf -- '- `%s`: Pass - %s\n' "$id" "$summary"
  done

  printf '\nlayout / clipping 케이스\n'
  for id in "${layout_ids[@]}"; do
    file="$dir/layout/${id}.md"
    summary="$(extract_prefixed_value "- Summary:" "$file")"
    printf -- '- `%s`: Pass - %s\n' "$id" "$summary"
  done

  cat <<'FOOTER'

공통 로그 확인
- `WidgetAction`
- `onOpenURL received`
- `consumePendingWidgetActionIfNeeded`

해결한 blocker
- `#617` start/end 액션 후 위젯·Live Activity·앱 상태 수렴 규칙
- `#692` 홈 화면 위젯 family별 clipping zero-base 정리
- `#731` WalkControlWidget 실기기 clipping과 start/end 액션 불능 회귀
- `#408` umbrella epic은 이미 종료되어, 이번 closure comment는 active blocker 기준으로만 게시합니다.

남은 blocker
- 없음

결론
- active widget blocker `#617`, `#692`, `#731` DoD를 충족했으므로 종료합니다.
FOOTER
}

render_auth_comment() {
  local dir="$1"
  local dns_path settings_path live_send_path negative_path ops_path
  dns_path="$(auth_smtp_bundle_dns_path "$dir")"
  settings_path="$(auth_smtp_bundle_settings_path "$dir")"
  live_send_path="$(auth_smtp_bundle_live_send_path "$dir")"
  negative_path="$(auth_smtp_bundle_negative_path "$dir")"
  ops_path="$(auth_smtp_bundle_ops_path "$dir")"

  bash scripts/validate_manual_evidence_pack.sh auth-smtp "$dir" >/dev/null || return 1

  local provider sender project spf dkim dmarc
  provider="$(extract_prefixed_value "- Provider:" "$dns_path")"
  sender="$(extract_prefixed_value "- Sender Domain:" "$dns_path")"
  project="$(extract_prefixed_value "- Supabase Project:" "$dns_path")"
  spf="$(extract_prefixed_value "- SPF:" "$dns_path")"
  dkim="$(extract_prefixed_value "- DKIM:" "$dns_path")"
  dmarc="$(extract_prefixed_value "- DMARC:" "$dns_path")"

  local signup_summary reset_summary change_summary
  signup_summary="$(collect_row_message "signup confirmation" "$live_send_path")"
  reset_summary="$(collect_row_message "password reset" "$live_send_path")"
  change_summary="$(collect_row_message "email change" "$live_send_path")"

  cat <<EOF2
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
- \`SMTP-101\`: $(extract_prefixed_value "- SMTP-101 Guard Evidence:" "$negative_path")
- \`SMTP-102\` or \`SMTP-103\`: $(extract_prefixed_value "- SMTP-102 Provider Event Evidence:" "$negative_path")

Rollback / rotation
- rollback path: $(extract_prefixed_value "- rollback path:" "$ops_path")
- secret rotation owner: $(extract_prefixed_value "- secret rotation owner:" "$ops_path")

남은 blocker
- 없음

결론
- \`#482\` DoD를 충족했으므로 종료합니다.
EOF2
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
