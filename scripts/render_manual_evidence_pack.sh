#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/render_manual_evidence_pack.sh <widget|auth-smtp> [--write] [--output <path>]

Examples:
  bash scripts/render_manual_evidence_pack.sh widget
  bash scripts/render_manual_evidence_pack.sh widget --write
  bash scripts/render_manual_evidence_pack.sh auth-smtp --output .codex_tmp/auth-smtp-pack.md

Options:
  --write         Write to default path under .codex_tmp/
  --output PATH   Write to a specific output path
  -h, --help      Print usage
EOF
}

die() {
  printf 'render_manual_evidence_pack.sh: %s\n' "$*" >&2
  exit 1
}

kind=""
write_mode=0
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    widget|auth-smtp)
      [[ -z "$kind" ]] || die "kind is already set to '$kind'"
      kind="$1"
      shift
      ;;
    --write)
      write_mode=1
      shift
      ;;
    --output|-o)
      [[ $# -ge 2 ]] || die "--output requires a path"
      output_path="$2"
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

[[ -n "$kind" ]] || {
  usage
  exit 1
}

case "$kind" in
  widget)
    pack_title="Widget Action Evidence Pack v1"
    related_issue="#408"
    runbook_path="docs/widget-action-real-device-evidence-runbook-v1.md"
    matrix_path="docs/widget-action-real-device-validation-matrix-v1.md"
    checklist_path="docs/widget-action-closure-checklist-v1.md"
    evidence_template_path="docs/widget-action-real-device-evidence-template-v1.md"
    closure_template_path="docs/widget-action-closure-comment-template-v1.md"
    default_output_path=".codex_tmp/widget-action-evidence-pack.md"
    ;;
  auth-smtp)
    pack_title="Auth SMTP Evidence Pack v1"
    related_issue="#482"
    runbook_path="docs/auth-smtp-rollout-evidence-runbook-v1.md"
    matrix_path="docs/auth-smtp-live-send-validation-matrix-v1.md"
    checklist_path="docs/auth-smtp-closure-checklist-v1.md"
    evidence_template_path="docs/auth-smtp-rollout-evidence-template-v1.md"
    closure_template_path="docs/auth-smtp-closure-comment-template-v1.md"
    default_output_path=".codex_tmp/auth-smtp-evidence-pack.md"
    ;;
esac

[[ -f "$runbook_path" ]] || die "missing runbook: $runbook_path"
[[ -f "$matrix_path" ]] || die "missing matrix: $matrix_path"
[[ -f "$checklist_path" ]] || die "missing checklist: $checklist_path"
[[ -f "$evidence_template_path" ]] || die "missing evidence template: $evidence_template_path"
[[ -f "$closure_template_path" ]] || die "missing closure template: $closure_template_path"

if [[ -z "$output_path" && "$write_mode" == "1" ]]; then
  output_path="$default_output_path"
fi

render_pack() {
  cat <<EOF
# $pack_title

- Related issue: $related_issue
- Generated at: $(date '+%Y-%m-%d %H:%M:%S %z')
- Runbook: \`$runbook_path\`
- Validation matrix: \`$matrix_path\`
- Closure checklist: \`$checklist_path\`
- Evidence template: \`$evidence_template_path\`
- Closure comment template: \`$closure_template_path\`

## Evidence Template

$(cat "$evidence_template_path")

## Closure Comment Template

$(cat "$closure_template_path")
EOF
}

if [[ -n "$output_path" ]]; then
  mkdir -p "$(dirname "$output_path")"
  render_pack > "$output_path"
  printf 'WROTE %s\n' "$output_path"
else
  render_pack
fi
