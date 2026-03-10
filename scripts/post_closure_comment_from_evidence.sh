#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/post_closure_comment_from_evidence.sh widget --issue 408 <evidence-dir-or-file> [--post] [--output <path>]
  bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue 482 <evidence-file> --negative-guard <text> --negative-provider-event <text> [--post] [--output <path>]

Notes:
  - Default mode is dry-run. The rendered closure comment is printed to stdout.
  - Use --post to actually publish the rendered comment with gh issue comment.
  - Surface and issue must match the canonical pair:
      widget -> #408
      auth-smtp -> #482
EOF
}

die() {
  printf 'post_closure_comment_from_evidence.sh: %s\n' "$*" >&2
  exit 1
}

canonical_issue_for_surface() {
  local surface="$1"
  case "$surface" in
    widget)
      printf '408'
      ;;
    auth-smtp)
      printf '482'
      ;;
    *)
      die "unsupported surface: $surface"
      ;;
  esac
}

kind=""
issue_number=""
evidence_path=""
negative_guard=""
negative_provider_event=""
post_mode=0
output_path=""
gh_bin="${DOGAREA_GH_BIN:-gh}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    widget|auth-smtp)
      [[ -z "$kind" ]] || die "surface is already set to '$kind'"
      kind="$1"
      shift
      ;;
    --issue)
      [[ $# -ge 2 ]] || die "--issue requires a value"
      issue_number="${2#\#}"
      shift 2
      ;;
    --negative-guard)
      [[ $# -ge 2 ]] || die "--negative-guard requires a value"
      negative_guard="$2"
      shift 2
      ;;
    --negative-provider-event)
      [[ $# -ge 2 ]] || die "--negative-provider-event requires a value"
      negative_provider_event="$2"
      shift 2
      ;;
    --post)
      post_mode=1
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
    --*)
      die "unknown argument: $1"
      ;;
    *)
      [[ -z "$evidence_path" ]] || die "evidence path is already set to '$evidence_path'"
      evidence_path="$1"
      shift
      ;;
  esac
done

[[ -n "$kind" ]] || {
  usage
  exit 1
}
[[ -n "$issue_number" ]] || die "--issue is required"
[[ -n "$evidence_path" ]] || die "evidence path is required"

expected_issue="$(canonical_issue_for_surface "$kind")"
if [[ "$issue_number" != "$expected_issue" ]]; then
  die "surface $kind must target issue #$expected_issue (got #$issue_number)"
fi

if [[ "$kind" == "auth-smtp" ]]; then
  [[ -n "$negative_guard" ]] || die "--negative-guard is required for auth-smtp"
  [[ -n "$negative_provider_event" ]] || die "--negative-provider-event is required for auth-smtp"
fi

rendered_output_path="$output_path"
cleanup_output=0
if [[ -z "$rendered_output_path" ]]; then
  rendered_output_path="$(mktemp)"
  cleanup_output=1
fi

cleanup() {
  if [[ "$cleanup_output" == "1" && -f "$rendered_output_path" ]]; then
    rm -f "$rendered_output_path"
  fi
}
trap cleanup EXIT

renderer_args=(
  "$kind"
  "$evidence_path"
)

if [[ "$kind" == "auth-smtp" ]]; then
  renderer_args+=(
    --negative-guard "$negative_guard"
    --negative-provider-event "$negative_provider_event"
  )
fi

renderer_args+=(--output "$rendered_output_path")

bash scripts/render_closure_comment_from_evidence.sh "${renderer_args[@]}" >/dev/null

if [[ "$post_mode" != "1" ]]; then
  cat "$rendered_output_path"
  printf '\n'
  printf 'DRY RUN: no GitHub comment was posted. Re-run with --post to publish to issue #%s.\n' "$issue_number" >&2
  exit 0
fi

command -v "$gh_bin" >/dev/null 2>&1 || die "gh binary not found: $gh_bin"
"$gh_bin" issue comment "$issue_number" --body-file "$rendered_output_path"
printf 'POSTED issue #%s using %s\n' "$issue_number" "$gh_bin"
