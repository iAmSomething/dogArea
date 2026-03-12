#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/post_closure_comment_from_evidence.sh widget --issue <408|617|692|731> <evidence-dir> [--post] [--output <path>]
  bash scripts/post_closure_comment_from_evidence.sh widget --all-related <evidence-dir> [--post] [--output <path>]
  bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue 482 <evidence-dir> [--post] [--output <path>]
USAGE
}

die() {
  printf 'post_closure_comment_from_evidence.sh: %s\n' "$*" >&2
  exit 1
}

issue_allowed_for_surface() {
  local surface="$1"
  local issue="$2"
  case "$surface" in
    widget)
      [[ "$issue" == "408" || "$issue" == "617" || "$issue" == "692" || "$issue" == "731" ]]
      ;;
    auth-smtp)
      [[ "$issue" == "482" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

kind=""
issue_number=""
evidence_path=""
all_related=0
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
    --all-related)
      all_related=1
      shift
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

[[ -n "$kind" ]] || { usage; exit 1; }
[[ -n "$evidence_path" ]] || die "evidence path is required"

if [[ "$all_related" == "1" ]]; then
  [[ "$kind" == "widget" ]] || die "--all-related is only supported for widget"
  [[ -z "$issue_number" ]] || die "--issue and --all-related cannot be used together"
else
  [[ -n "$issue_number" ]] || die "--issue is required"
  if ! issue_allowed_for_surface "$kind" "$issue_number"; then
    case "$kind" in
      widget) die "surface widget must target one of #408, #617, #692, #731 (got #$issue_number)" ;;
      auth-smtp) die "surface auth-smtp must target issue #482 (got #$issue_number)" ;;
    esac
  fi
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

renderer_args=("$kind" "$evidence_path")
renderer_args+=(--output "$rendered_output_path")

bash scripts/render_closure_comment_from_evidence.sh "${renderer_args[@]}" >/dev/null

if [[ "$post_mode" != "1" ]]; then
  cat "$rendered_output_path"
  printf '\n'
  if [[ "$all_related" == "1" ]]; then
    printf 'DRY RUN: no GitHub comment was posted. Re-run with --post to publish to issues #731, #617, and #692.\n' >&2
  else
    printf 'DRY RUN: no GitHub comment was posted. Re-run with --post to publish to issue #%s.\n' "$issue_number" >&2
  fi
  exit 0
fi

command -v "$gh_bin" >/dev/null 2>&1 || die "gh binary not found: $gh_bin"
if [[ "$all_related" == "1" ]]; then
  posted_issues=(731 617 692)
  for posted_issue in "${posted_issues[@]}"; do
    "$gh_bin" issue comment "$posted_issue" --body-file "$rendered_output_path"
  done
  printf 'POSTED issues #731, #617, and #692 using %s\n' "$gh_bin"
else
  "$gh_bin" issue comment "$issue_number" --body-file "$rendered_output_path"
  printf 'POSTED issue #%s using %s\n' "$issue_number" "$gh_bin"
fi
