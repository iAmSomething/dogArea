#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/manual_blocker_evidence_status.sh [widget|auth-smtp] [--write-missing]
USAGE
}

die() {
  printf 'manual_blocker_evidence_status.sh: %s\n' "$*" >&2
  exit 1
}

kind_filter=""
write_missing=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    widget|auth-smtp)
      [[ -z "$kind_filter" ]] || die "surface is already set to '$kind_filter'"
      kind_filter="$1"
      shift
      ;;
    --write-missing)
      write_missing=1
      shift
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

surface_pack_path() {
  case "$1" in
    widget) printf '%s' "${DOGAREA_WIDGET_EVIDENCE_PATH:-.codex_tmp/widget-real-device-evidence}" ;;
    auth-smtp) printf '%s' "${DOGAREA_AUTH_SMTP_EVIDENCE_PATH:-.codex_tmp/auth-smtp-evidence-pack.md}" ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_issue_number() {
  case "$1" in
    widget) printf '408' ;;
    auth-smtp) printf '482' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_related_issues() {
  case "$1" in
    widget) printf '#617 #692 #731' ;;
    auth-smtp) printf 'none' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_title() {
  case "$1" in
    widget) printf 'widget real-device blocker evidence' ;;
    auth-smtp) printf 'auth smtp rollout evidence' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_render_command() {
  printf 'bash scripts/render_manual_evidence_pack.sh %s --output %q' "$1" "$2"
}

surface_validate_command() {
  printf 'bash scripts/validate_manual_evidence_pack.sh %s %q' "$1" "$2"
}

surface_closure_render_command() {
  case "$1" in
    widget) printf 'bash scripts/render_closure_comment_from_evidence.sh widget %q --write' "$2" ;;
    auth-smtp) printf "bash scripts/render_closure_comment_from_evidence.sh auth-smtp %q --negative-guard %q --negative-provider-event %q --write" "$2" "SMTP-101: cooldown suppressed with retry_after_seconds=60" "SMTP-102: provider dashboard event summary" ;;
  esac
}

surface_closure_post_command() {
  local surface="$1"
  local issue_number="$2"
  local pack_path="$3"
  case "$surface" in
    widget) printf 'bash scripts/post_closure_comment_from_evidence.sh widget --issue %s %q --post' "$issue_number" "$pack_path" ;;
    auth-smtp) printf "bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue %s %q --negative-guard %q --negative-provider-event %q --post" "$issue_number" "$pack_path" "SMTP-101: cooldown suppressed with retry_after_seconds=60" "SMTP-102: provider dashboard event summary" ;;
  esac
}

surface_bundle_post_command() {
  local surface="$1"
  local pack_path="$2"
  case "$surface" in
    widget) printf 'bash scripts/post_closure_comment_from_evidence.sh widget --all-related %q --post' "$pack_path" ;;
    auth-smtp) printf 'n/a' ;;
  esac
}

surface_issue_state() {
  local issue_number="$1"
  if [[ "${DOGAREA_SKIP_ISSUE_STATE:-0}" == "1" ]]; then
    printf 'skipped'
    return
  fi
  local gh_bin="${DOGAREA_GH_BIN:-gh}"
  if ! command -v "$gh_bin" >/dev/null 2>&1; then
    printf 'unknown'
    return
  fi
  local state
  state="$($gh_bin issue view "$issue_number" --json state -q .state 2>/dev/null || true)"
  if [[ -z "$state" ]]; then
    printf 'unknown'
  else
    printf '%s' "$state"
  fi
}

render_missing_pack_if_needed() {
  local surface="$1"
  local pack_path="$2"
  if [[ -e "$pack_path" || "$write_missing" != "1" ]]; then
    return
  fi
  mkdir -p "$(dirname "$pack_path")"
  bash scripts/render_manual_evidence_pack.sh "$surface" --output "$pack_path" >/dev/null
}

surface_status() {
  local surface="$1"
  local pack_path="$2"
  if [[ ! -e "$pack_path" ]]; then
    printf 'missing'
    return
  fi

  if bash scripts/validate_manual_evidence_pack.sh "$surface" "$pack_path" >/tmp/dogarea_manual_blocker_status.$$ 2>&1; then
    rm -f /tmp/dogarea_manual_blocker_status.$$
    printf 'complete'
    return
  fi

  cat /tmp/dogarea_manual_blocker_status.$$ >&2
  rm -f /tmp/dogarea_manual_blocker_status.$$
  printf 'incomplete'
}

print_surface_status() {
  local surface="$1"
  local issue_number="$(surface_issue_number "$surface")"
  local issue_state="$(surface_issue_state "$issue_number")"
  local pack_path="$(surface_pack_path "$surface")"
  render_missing_pack_if_needed "$surface" "$pack_path"
  local status="$(surface_status "$surface" "$pack_path")"

  printf '== %s ==\n' "$surface"
  printf 'title: %s\n' "$(surface_title "$surface")"
  printf 'issue: #%s (%s)\n' "$issue_number" "$issue_state"
  printf 'related-issues: %s\n' "$(surface_related_issues "$surface")"
  printf 'pack: %s\n' "$pack_path"
  printf 'status: %s\n' "$status"
  printf 'next-render: %s\n' "$(surface_render_command "$surface" "$pack_path")"
  printf 'next-validate: %s\n' "$(surface_validate_command "$surface" "$pack_path")"
  printf 'next-render-closure: %s\n' "$(surface_closure_render_command "$surface" "$pack_path")"
  printf 'next-post-closure: %s\n' "$(surface_closure_post_command "$surface" "$issue_number" "$pack_path")"
  if [[ "$surface" == "widget" ]]; then
    printf 'next-post-closure-bundle: %s\n' "$(surface_bundle_post_command "$surface" "$pack_path")"
  fi
  printf '\n'
}

surfaces=(widget auth-smtp)
[[ -n "$kind_filter" ]] && surfaces=("$kind_filter")

for surface in "${surfaces[@]}"; do
  print_surface_status "$surface"
done
