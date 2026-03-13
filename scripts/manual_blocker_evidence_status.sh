#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/auth_smtp_evidence_bundle.sh"
source "$ROOT_DIR/scripts/lib/manual_evidence_prefill_sources.sh"
source "$ROOT_DIR/scripts/lib/widget_simulator_baseline_status.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/manual_blocker_evidence_status.sh [widget|auth-smtp] [--write-missing]
  bash scripts/manual_blocker_evidence_status.sh [widget|auth-smtp] --markdown [--output <path>] [--write-missing]
  bash scripts/manual_blocker_evidence_status.sh [widget|auth-smtp] [--raw-errors]
  bash scripts/manual_blocker_evidence_status.sh [widget|auth-smtp] [--apply-prefill]
USAGE
}

die() {
  printf 'manual_blocker_evidence_status.sh: %s\n' "$*" >&2
  exit 1
}

kind_filter=""
write_missing=0
markdown_mode=0
output_path=""
raw_errors=0
apply_prefill=0

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
    --markdown)
      markdown_mode=1
      shift
      ;;
    --output|-o)
      [[ $# -ge 2 ]] || die "--output requires a path"
      output_path="$2"
      shift 2
      ;;
    --raw-errors)
      raw_errors=1
      shift
      ;;
    --apply-prefill)
      apply_prefill=1
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

[[ -z "$output_path" || "$markdown_mode" == "1" ]] || die "--output requires --markdown"

surface_pack_path() {
  case "$1" in
    widget) printf '%s' "${DOGAREA_WIDGET_EVIDENCE_PATH:-.codex_tmp/widget-real-device-evidence}" ;;
    auth-smtp) auth_smtp_bundle_default_path ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_issue_number() {
  case "$1" in
    widget) printf '731' ;;
    auth-smtp) printf '482' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_issue_url() {
  printf 'https://github.com/iAmSomething/dogArea/issues/%s' "$1"
}

surface_related_issues() {
  case "$1" in
    widget) printf '#617 #692' ;;
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
  case "$1" in
    widget) printf 'bash scripts/render_manual_evidence_pack.sh widget --output %q --prefill-from-env' "$2" ;;
    auth-smtp) printf 'bash scripts/render_manual_evidence_pack.sh auth-smtp --output %q --prefill-from-env' "$2" ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_validate_command() {
  printf 'bash scripts/validate_manual_evidence_pack.sh %s %q' "$1" "$2"
}

surface_prefill_command() {
  printf 'bash scripts/prefill_manual_evidence_pack.sh %s %q' "$1" "$2"
}

surface_apply_prefill_status_command() {
  printf 'bash scripts/manual_blocker_evidence_status.sh %s --apply-prefill' "$1"
}

surface_prefill_env_command() {
  printf 'bash scripts/print_manual_evidence_prefill_env.sh %s' "$1"
}

surface_prefill_bootstrap_command() {
  printf 'source <(bash scripts/print_manual_evidence_prefill_env.sh %s) && bash scripts/manual_blocker_evidence_status.sh %s --apply-prefill' "$1" "$1"
}

surface_closure_render_command() {
  case "$1" in
    widget) printf 'bash scripts/render_closure_comment_from_evidence.sh widget %q --write' "$2" ;;
    auth-smtp) printf 'bash scripts/render_closure_comment_from_evidence.sh auth-smtp %q --write' "$2" ;;
  esac
}

surface_closure_post_command() {
  local surface="$1"
  local issue_number="$2"
  local pack_path="$3"
  case "$surface" in
    widget) printf 'bash scripts/post_closure_comment_from_evidence.sh widget --issue %s %q --post' "$issue_number" "$pack_path" ;;
    auth-smtp) printf 'bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue %s %q --post' "$issue_number" "$pack_path" ;;
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

surface_archive_command() {
  printf 'bash scripts/archive_manual_evidence_pack.sh %s %q' "$1" "$2"
}

surface_widget_action_baseline_refresh_command() {
  printf "bash scripts/run_widget_action_regression_ui_tests.sh 'platform=iOS Simulator,name=iPhone 17'"
}

surface_widget_layout_baseline_refresh_command() {
  printf 'bash scripts/run_pr_fast_smoke_widget_layout_checks.sh'
}

widget_expected_baseline_coverage() {
  case "$1" in
    action-regression) printf 'WD-001,WD-002,WD-003,WD-004,WD-005,WD-006,WD-007,WD-008' ;;
    layout-fast-smoke) printf 'WL-001,WL-002,WL-003,WL-004,WL-005,WL-006,WL-007,WL-008' ;;
    *) return 1 ;;
  esac
}

widget_simulator_baseline_value() {
  local suite="$1"
  local key="$2"
  local status_path
  status_path="$(widget_simulator_baseline_path "$suite")"
  [[ -f "$status_path" ]] || return 1
  awk -F= -v key="$key" '$1 == key { sub($1 FS, ""); print; exit }' "$status_path"
}

widget_case_count_from_csv() {
  local csv="${1:-}"
  [[ -n "$csv" ]] || {
    printf '0'
    return
  }
  awk -F',' '{ print NF }' <<<"$csv"
}

widget_baseline_coverage_csv() {
  local suite="$1"
  local coverage
  coverage="$(widget_simulator_baseline_value "$suite" "coverage" 2>/dev/null || true)"
  if [[ -n "$coverage" ]]; then
    printf '%s' "$coverage"
    return
  fi
  widget_expected_baseline_coverage "$suite" 2>/dev/null || true
}

widget_baseline_coverage_plain() {
  local suite="$1"
  local coverage
  coverage="$(widget_baseline_coverage_csv "$suite")"
  [[ -n "$coverage" ]] || return
  printf '    coverage: %s\n' "$coverage"
}

widget_baseline_coverage_markdown() {
  local suite="$1"
  local coverage
  coverage="$(widget_baseline_coverage_csv "$suite")"
  [[ -n "$coverage" ]] || return
  printf -- '  - Coverage: `%s`\n' "$coverage"
}

widget_simulator_coverage_summary_plain() {
  local action_coverage layout_coverage action_count layout_count
  action_coverage="$(widget_baseline_coverage_csv "action-regression")"
  layout_coverage="$(widget_baseline_coverage_csv "layout-fast-smoke")"
  action_count="$(widget_case_count_from_csv "$action_coverage")"
  layout_count="$(widget_case_count_from_csv "$layout_coverage")"
  printf 'simulator-coverage-summary: action %s/8, layout %s/8\n' "$action_count" "$layout_count"
}

widget_simulator_coverage_summary_markdown() {
  local action_coverage layout_coverage action_count layout_count
  action_coverage="$(widget_baseline_coverage_csv "action-regression")"
  layout_coverage="$(widget_baseline_coverage_csv "layout-fast-smoke")"
  action_count="$(widget_case_count_from_csv "$action_coverage")"
  layout_count="$(widget_case_count_from_csv "$layout_coverage")"
  printf -- '- Coverage Summary: `action %s/8`, `layout %s/8`\n' "$action_count" "$layout_count"
}

surface_simulator_baseline_plain() {
  local surface="$1"
  [[ "$surface" == "widget" ]] || return

  local action_status action_ran_at layout_status layout_ran_at
  action_status="$(widget_simulator_baseline_value "action-regression" "status" 2>/dev/null || true)"
  action_ran_at="$(widget_simulator_baseline_value "action-regression" "ran_at_utc" 2>/dev/null || true)"
  layout_status="$(widget_simulator_baseline_value "layout-fast-smoke" "status" 2>/dev/null || true)"
  layout_ran_at="$(widget_simulator_baseline_value "layout-fast-smoke" "ran_at_utc" 2>/dev/null || true)"

  printf 'simulator-baseline:\n'
  if [[ -n "$action_status" ]]; then
    printf '  - action-regression: %s (%s)\n' "$action_status" "$action_ran_at"
    widget_baseline_coverage_plain "action-regression"
  else
    printf '  - action-regression: missing\n'
    widget_baseline_coverage_plain "action-regression"
  fi
  if [[ -n "$layout_status" ]]; then
    printf '  - layout-fast-smoke: %s (%s)\n' "$layout_status" "$layout_ran_at"
    widget_baseline_coverage_plain "layout-fast-smoke"
  else
    printf '  - layout-fast-smoke: missing\n'
    widget_baseline_coverage_plain "layout-fast-smoke"
  fi
  widget_simulator_coverage_summary_plain
  printf 'next-refresh-widget-action-baseline: %s\n' "$(surface_widget_action_baseline_refresh_command)"
  printf 'next-refresh-widget-layout-baseline: %s\n' "$(surface_widget_layout_baseline_refresh_command)"
}

surface_simulator_baseline_markdown() {
  local surface="$1"
  [[ "$surface" == "widget" ]] || return

  local action_status action_ran_at layout_status layout_ran_at
  action_status="$(widget_simulator_baseline_value "action-regression" "status" 2>/dev/null || true)"
  action_ran_at="$(widget_simulator_baseline_value "action-regression" "ran_at_utc" 2>/dev/null || true)"
  layout_status="$(widget_simulator_baseline_value "layout-fast-smoke" "status" 2>/dev/null || true)"
  layout_ran_at="$(widget_simulator_baseline_value "layout-fast-smoke" "ran_at_utc" 2>/dev/null || true)"

  printf '### Simulator Baseline\n'
  if [[ -n "$action_status" ]]; then
    printf -- '- Action Regression: `%s` (`%s`)\n' "$action_status" "$action_ran_at"
    widget_baseline_coverage_markdown "action-regression"
  else
    printf -- '- Action Regression: `missing`\n'
    widget_baseline_coverage_markdown "action-regression"
  fi
  if [[ -n "$layout_status" ]]; then
    printf -- '- Layout Fast Smoke: `%s` (`%s`)\n' "$layout_status" "$layout_ran_at"
    widget_baseline_coverage_markdown "layout-fast-smoke"
  else
    printf -- '- Layout Fast Smoke: `missing`\n'
    widget_baseline_coverage_markdown "layout-fast-smoke"
  fi
  widget_simulator_coverage_summary_markdown
  printf -- '- Refresh Action Baseline: `%s`\n' "$(surface_widget_action_baseline_refresh_command)"
  printf -- '- Refresh Layout Baseline: `%s`\n' "$(surface_widget_layout_baseline_refresh_command)"
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
  if [[ "$surface" == "auth-smtp" ]]; then
    bash scripts/render_manual_evidence_pack.sh auth-smtp --output "$pack_path" --prefill-from-env >/dev/null
  else
    bash scripts/render_manual_evidence_pack.sh "$surface" --output "$pack_path" --prefill-from-env >/dev/null
  fi
}

apply_prefill_if_requested() {
  local surface="$1"
  local pack_path="$2"
  if [[ "$apply_prefill" != "1" || ! -e "$pack_path" ]]; then
    return
  fi
  bash scripts/prefill_manual_evidence_pack.sh "$surface" "$pack_path" >/dev/null
}

surface_has_prefill_gaps() {
  local surface="$1"
  local capture_path="$2"
  case "$surface" in
    widget)
      grep -Eq '^ - (empty value|missing line): .* :: - (Date|Tester|Device / OS|App Build):$' "$capture_path"
      ;;
    auth-smtp)
      grep -Eq '^ - (empty value|missing line): .*01-dns-verification\.md :: ' "$capture_path" ||
      grep -Eq '^ - (empty value|missing line): .*02-supabase-smtp-settings\.md :: ' "$capture_path"
      ;;
    *)
      return 1
      ;;
  esac
}

surface_missing_prefill_envs() {
  local surface="$1"
  case "$surface" in
    widget)
      local missing=()
      local device_source build_source
      device_source="$(widget_prefill_device_os_source)"
      build_source="$(widget_prefill_app_build_source)"
      [[ "$device_source" == "missing" ]] && missing+=("DOGAREA_WIDGET_EVIDENCE_DEVICE_OS")
      [[ "$build_source" == "missing" ]] && missing+=("DOGAREA_WIDGET_EVIDENCE_APP_BUILD")
      printf '%s\n' "${missing[@]:-}" | sed '/^$/d'
      ;;
    auth-smtp)
      local keys=(
        DOGAREA_AUTH_SMTP_PROJECT
        DOGAREA_AUTH_SMTP_PROVIDER
        DOGAREA_AUTH_SMTP_SENDER_DOMAIN
        DOGAREA_AUTH_SMTP_DNS_SPF
        DOGAREA_AUTH_SMTP_DNS_DKIM
        DOGAREA_AUTH_SMTP_DNS_DMARC
        DOGAREA_AUTH_SMTP_PROVIDER_VERIFIED_AT
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
      local key
      for key in "${keys[@]}"; do
        [[ -n "${!key:-}" ]] || printf '%s\n' "$key"
      done
      ;;
    *)
      return 1
      ;;
  esac
}

surface_has_missing_prefill_envs() {
  local surface="$1"
  [[ -n "$(surface_missing_prefill_envs "$surface")" ]]
}

surface_missing_prefill_env_summary_plain() {
  local surface="$1"
  local missing
  missing="$(surface_missing_prefill_envs "$surface" | awk 'BEGIN { first = 1 } { if (!first) printf ", "; printf "%s", $0; first = 0 }')"
  [[ -n "$missing" ]] || return
  printf 'missing-prefill-env: %s\n' "$missing"
}

surface_missing_prefill_env_summary_markdown() {
  local surface="$1"
  local missing
  missing="$(surface_missing_prefill_envs "$surface" | awk 'BEGIN { first = 1 } { if (!first) printf ", "; printf "%s", $0; first = 0 }')"
  [[ -n "$missing" ]] || return
  printf -- '- Missing Prefill Env: `%s`\n' "$missing"
}

surface_prefill_resolution_plain() {
  local surface="$1"
  case "$surface" in
    widget)
      local device_value device_source build_value build_source
      device_value="$(widget_prefill_device_os)"
      device_source="$(widget_prefill_device_os_source)"
      build_value="$(widget_prefill_app_build)"
      build_source="$(widget_prefill_app_build_source)"
      [[ -n "$device_value" ]] && printf 'prefill-device-os: %s [source=%s]\n' "$device_value" "$device_source"
      [[ -n "$build_value" ]] && printf 'prefill-app-build: %s [source=%s]\n' "$build_value" "$build_source"
      ;;
  esac
  return 0
}

surface_prefill_resolution_markdown() {
  local surface="$1"
  case "$surface" in
    widget)
      local device_value device_source build_value build_source
      device_value="$(widget_prefill_device_os)"
      device_source="$(widget_prefill_device_os_source)"
      build_value="$(widget_prefill_app_build)"
      build_source="$(widget_prefill_app_build_source)"
      [[ -n "$device_value" ]] && printf -- '- Prefill Device / OS: `%s` (source `%s`)\n' "$device_value" "$device_source"
      [[ -n "$build_value" ]] && printf -- '- Prefill App Build: `%s` (source `%s`)\n' "$build_value" "$build_source"
      ;;
  esac
  return 0
}

surface_prefill_gap_summary_plain() {
  local surface="$1"
  local capture_path="$2"
  case "$surface" in
    widget)
      awk '
        /^ - (empty value|missing line): / {
          split($0, detailParts, " :: ")
          filePath = detailParts[1]
          field = detailParts[2]
          if (field !~ /Date|Tester|Device \/ OS|App Build/) next
          caseRef = filePath
          sub(/^.*\//, "", caseRef)
          sub(/\.md$/, "", caseRef)
          if (!(caseRef in seen)) {
            seen[caseRef] = 1
            count++
          }
        }
        END {
          if (count > 0) {
            printf "prefill-opportunity: metadata gaps detected in %d cases\n", count
          }
        }
      ' "$capture_path"
      ;;
    auth-smtp)
      awk '
        /^ - (empty value|missing line): / {
          split($0, detailParts, " :: ")
          filePath = detailParts[1]
          fileRef = filePath
          sub(/^.*\//, "", fileRef)
          if (fileRef != "01-dns-verification.md" && fileRef != "02-supabase-smtp-settings.md") next
          if (!(fileRef in seen)) {
            seen[fileRef] = 1
            count++
          }
        }
        END {
          if (count > 0) {
            printf "prefill-opportunity: metadata gaps detected in %d files\n", count
          }
        }
      ' "$capture_path"
      ;;
  esac
}

surface_prefill_gap_summary_markdown() {
  local surface="$1"
  local capture_path="$2"
  case "$surface" in
    widget)
      awk '
        /^ - (empty value|missing line): / {
          split($0, detailParts, " :: ")
          filePath = detailParts[1]
          field = detailParts[2]
          if (field !~ /Date|Tester|Device \/ OS|App Build/) next
          caseRef = filePath
          sub(/^.*\//, "", caseRef)
          sub(/\.md$/, "", caseRef)
          if (!(caseRef in seen)) {
            seen[caseRef] = 1
            count++
          }
        }
        END {
          if (count > 0) {
            printf "- Prefill Opportunity: metadata gaps in `%d` cases\n", count
          }
        }
      ' "$capture_path"
      ;;
    auth-smtp)
      awk '
        /^ - (empty value|missing line): / {
          split($0, detailParts, " :: ")
          filePath = detailParts[1]
          fileRef = filePath
          sub(/^.*\//, "", fileRef)
          if (fileRef != "01-dns-verification.md" && fileRef != "02-supabase-smtp-settings.md") next
          if (!(fileRef in seen)) {
            seen[fileRef] = 1
            count++
          }
        }
        END {
          if (count > 0) {
            printf "- Prefill Opportunity: metadata gaps in `%d` files\n", count
          }
        }
      ' "$capture_path"
      ;;
  esac
}

surface_status_and_capture() {
  local surface="$1"
  local pack_path="$2"
  local capture_path="$3"
  if [[ ! -e "$pack_path" ]]; then
    printf 'missing'
    return
  fi

  if bash scripts/validate_manual_evidence_pack.sh "$surface" "$pack_path" >"$capture_path" 2>&1; then
    printf 'complete'
    return
  fi

  if [[ "$raw_errors" == "1" ]]; then
    cat "$capture_path" >&2
  fi
  printf 'incomplete'
}

surface_gap_summary_plain() {
  local surface="$1"
  local capture_path="$2"
  case "$surface" in
    widget)
      awk '
        function append_bucket(key, value, composite, current) {
          composite = key SUBSEP value
          if (seenBuckets[composite]) return
          seenBuckets[composite] = 1
          current = categories[key]
          if (current == "") {
            categories[key] = value
          } else {
            categories[key] = current ", " value
          }
        }
        /^ - / {
          errorCount++
          line = substr($0, 4)
          split(line, headParts, ": ")
          kind = headParts[1]
          remainder = substr(line, length(kind) + 3)

          split(remainder, detailParts, " :: ")
          filePath = detailParts[1]
          if (filePath == "") next

          caseRef = filePath
          sub(/^.*\//, "", caseRef)
          sub(/\.md$/, "", caseRef)
          if (caseRef !~ /^(WD|WL)-[0-9][0-9][0-9]$/) next

          if (!(caseRef in seen)) {
            seen[caseRef] = 1
            order[++orderCount] = caseRef
            if (caseRef ~ /^WD-/) {
              actionCount++
            } else {
              layoutCount++
            }
          }

          bucket = "other"
          if (kind == "empty value" || kind == "missing line") {
            field = detailParts[2]
            if (field ~ /Date|Tester|Device \/ OS|App Build/) {
              bucket = "metadata"
            } else if (field ~ /Summary|Final Screen|Pass \/ Fail/) {
              bucket = "result"
            } else {
              bucket = "fields"
            }
          } else if (kind == "missing asset file") {
            bucket = "assets"
            assetPath = detailParts[3]
            if (assetPath != "") {
              composite = caseRef SUBSEP assetPath
              if (!seenCaptureAssets[composite]) {
                seenCaptureAssets[composite] = 1
                if (captureAssets[caseRef] == "") {
                  captureAssets[caseRef] = assetPath
                } else {
                  captureAssets[caseRef] = captureAssets[caseRef] ", " assetPath
                }
              }
            }
          } else if (kind == "placeholder literal remains") {
            bucket = "placeholder logs"
          } else if (kind == "non-pass outcome") {
            bucket = "result"
          }
          append_bucket(caseRef, bucket)
        }
        END {
          if (orderCount == 0) exit
          printf "gap-summary: %d incomplete cases (action %d, layout %d, total-errors %d)\n", orderCount, actionCount, layoutCount, errorCount
          nextFill = order[1]
          if (nextFill ~ /^WD-/) {
            printf "next-fill: action/%s.md\n", nextFill
          } else {
            printf "next-fill: layout/%s.md\n", nextFill
          }
          if (captureAssets[nextFill] != "") {
            printf "next-capture-assets: %s\n", captureAssets[nextFill]
          }
          printf "gap-cases:\n"
          for (i = 1; i <= orderCount; i++) {
            current = order[i]
            printf "  - %s: %s\n", current, categories[current]
          }
        }
      ' "$capture_path"
      ;;
    auth-smtp)
      awk '
        function append_bucket(key, value, composite, current) {
          composite = key SUBSEP value
          if (seenBuckets[composite]) return
          seenBuckets[composite] = 1
          current = categories[key]
          if (current == "") {
            categories[key] = value
          } else {
            categories[key] = current ", " value
          }
        }
        function append_capture_asset(key, value, composite, current) {
          composite = key SUBSEP value
          if (seenCaptureAssets[composite]) return
          seenCaptureAssets[composite] = 1
          current = captureAssets[key]
          if (current == "") {
            captureAssets[key] = value
          } else {
            captureAssets[key] = current ", " value
          }
        }
        /^ - / {
          errorCount++
          line = substr($0, 4)
          split(line, headParts, ": ")
          kind = headParts[1]
          remainder = substr(line, length(kind) + 3)
          fileRef = ""
          bucket = "other"

          if (kind == "incomplete scenario row") {
            fileRef = "03-live-send-results.md"
            bucket = "scenario rows"
          } else {
            split(remainder, detailParts, " :: ")
            filePath = detailParts[1]
            if (filePath == "") next

            fileRef = filePath
            sub(/^.*\//, "", fileRef)

            field = detailParts[2]
            if (fileRef == "01-dns-verification.md") {
              if (kind == "missing asset file") {
                bucket = "asset"
              } else {
                bucket = "dns metadata"
              }
            } else if (fileRef == "02-supabase-smtp-settings.md") {
              if (kind == "missing asset file") {
                bucket = "asset"
              } else {
                bucket = "smtp settings"
              }
            } else if (fileRef == "03-live-send-results.md") {
              if (kind == "missing asset file") {
                bucket = "mailbox assets"
              } else {
                bucket = "scenario rows"
              }
            } else if (fileRef == "04-negative-evidence.md") {
              if (kind == "missing asset file") {
                bucket = "asset"
              } else {
                bucket = "negative evidence"
              }
            } else if (fileRef == "05-rollback-rotation.md") {
              bucket = "rollback readiness"
            } else if (fileRef == "06-final-decision.md") {
              if (kind == "non-pass outcome") {
                bucket = "final decision"
              } else {
                bucket = "closure fields"
              }
            }
          }

          if (!(fileRef in seen)) {
            seen[fileRef] = 1
            order[++orderCount] = fileRef
          }
          append_bucket(fileRef, bucket)
        }
        END {
          if (orderCount == 0) exit
          printf "gap-summary: %d incomplete files (total-errors %d)\n", orderCount, errorCount
          printf "next-fill: %s\n", order[1]
          printf "gap-files:\n"
          for (i = 1; i <= orderCount; i++) {
            current = order[i]
            printf "  - %s: %s\n", current, categories[current]
          }
        }
      ' "$capture_path"
      ;;
  esac
}

surface_gap_summary_markdown() {
  local surface="$1"
  local capture_path="$2"
  case "$surface" in
    widget)
      awk '
        function append_bucket(key, value, composite, current) {
          composite = key SUBSEP value
          if (seenBuckets[composite]) return
          seenBuckets[composite] = 1
          current = categories[key]
          if (current == "") {
            categories[key] = value
          } else {
            categories[key] = current ", " value
          }
        }
        /^ - / {
          errorCount++
          line = substr($0, 4)
          split(line, headParts, ": ")
          kind = headParts[1]
          remainder = substr(line, length(kind) + 3)

          split(remainder, detailParts, " :: ")
          filePath = detailParts[1]
          if (filePath == "") next

          caseRef = filePath
          sub(/^.*\//, "", caseRef)
          sub(/\.md$/, "", caseRef)
          if (caseRef !~ /^(WD|WL)-[0-9][0-9][0-9]$/) next

          if (!(caseRef in seen)) {
            seen[caseRef] = 1
            order[++orderCount] = caseRef
            if (caseRef ~ /^WD-/) {
              actionCount++
            } else {
              layoutCount++
            }
          }

          bucket = "other"
          if (kind == "empty value" || kind == "missing line") {
            field = detailParts[2]
            if (field ~ /Date|Tester|Device \/ OS|App Build/) {
              bucket = "metadata"
            } else if (field ~ /Summary|Final Screen|Pass \/ Fail/) {
              bucket = "result"
            } else {
              bucket = "fields"
            }
          } else if (kind == "missing asset file") {
            bucket = "assets"
            assetPath = detailParts[3]
            if (assetPath != "") {
              composite = caseRef SUBSEP assetPath
              if (!seenCaptureAssets[composite]) {
                seenCaptureAssets[composite] = 1
                if (captureAssets[caseRef] == "") {
                  captureAssets[caseRef] = assetPath
                } else {
                  captureAssets[caseRef] = captureAssets[caseRef] ", " assetPath
                }
              }
            }
          } else if (kind == "placeholder literal remains") {
            bucket = "placeholder logs"
          } else if (kind == "non-pass outcome") {
            bucket = "result"
          }
          append_bucket(caseRef, bucket)
        }
        END {
          if (orderCount == 0) exit
          printf "### Gap Summary\n"
          printf "- Incomplete Cases: `%d` (`action %d`, `layout %d`, `errors %d`)\n", orderCount, actionCount, layoutCount, errorCount
          nextFill = order[1]
          if (nextFill ~ /^WD-/) {
            printf "- Next Fill: `action/%s.md`\n", nextFill
          } else {
            printf "- Next Fill: `layout/%s.md`\n", nextFill
          }
          if (captureAssets[nextFill] != "") {
            split(captureAssets[nextFill], captureParts, ", ")
            captureLine = ""
            for (i = 1; i <= length(captureParts); i++) {
              if (captureParts[i] == "") continue
              if (captureLine == "") {
                captureLine = "`" captureParts[i] "`"
              } else {
                captureLine = captureLine ", `" captureParts[i] "`"
              }
            }
            if (captureLine != "") {
              printf "- Next Capture Assets: %s\n", captureLine
            }
          }
          printf "- Case Buckets:\n"
          for (i = 1; i <= orderCount; i++) {
            current = order[i]
            printf "  - `%s`: %s\n", current, categories[current]
          }
        }
      ' "$capture_path"
      ;;
    auth-smtp)
      awk '
        function append_bucket(key, value, composite, current) {
          composite = key SUBSEP value
          if (seenBuckets[composite]) return
          seenBuckets[composite] = 1
          current = categories[key]
          if (current == "") {
            categories[key] = value
          } else {
            categories[key] = current ", " value
          }
        }
        /^ - / {
          errorCount++
          line = substr($0, 4)
          split(line, headParts, ": ")
          kind = headParts[1]
          remainder = substr(line, length(kind) + 3)
          fileRef = ""
          bucket = "other"

          if (kind == "incomplete scenario row") {
            fileRef = "03-live-send-results.md"
            bucket = "scenario rows"
          } else {
            split(remainder, detailParts, " :: ")
            filePath = detailParts[1]
            if (filePath == "") next

            fileRef = filePath
            sub(/^.*\//, "", fileRef)

            field = detailParts[2]
            if (fileRef == "01-dns-verification.md") {
              if (kind == "missing asset file") {
                bucket = "asset"
              } else {
                bucket = "dns metadata"
              }
            } else if (fileRef == "02-supabase-smtp-settings.md") {
              if (kind == "missing asset file") {
                bucket = "asset"
              } else {
                bucket = "smtp settings"
              }
            } else if (fileRef == "03-live-send-results.md") {
              if (kind == "missing asset file") {
                bucket = "mailbox assets"
              } else {
                bucket = "scenario rows"
              }
            } else if (fileRef == "04-negative-evidence.md") {
              if (kind == "missing asset file") {
                bucket = "asset"
              } else {
                bucket = "negative evidence"
              }
            } else if (fileRef == "05-rollback-rotation.md") {
              bucket = "rollback readiness"
            } else if (fileRef == "06-final-decision.md") {
              if (kind == "non-pass outcome") {
                bucket = "final decision"
              } else {
                bucket = "closure fields"
              }
            }
          }

          if (!(fileRef in seen)) {
            seen[fileRef] = 1
            order[++orderCount] = fileRef
          }
          append_bucket(fileRef, bucket)
        }
        END {
          if (orderCount == 0) exit
          printf "### Gap Summary\n"
          printf "- Incomplete Files: `%d` (`errors %d`)\n", orderCount, errorCount
          printf "- Next Fill: `%s`\n", order[1]
          printf "- File Buckets:\n"
          for (i = 1; i <= orderCount; i++) {
            current = order[i]
            printf "  - `%s`: %s\n", current, categories[current]
          }
        }
      ' "$capture_path"
      ;;
  esac
}

print_surface_status() {
  local surface="$1"
  local issue_number="$(surface_issue_number "$surface")"
  local issue_state="$(surface_issue_state "$issue_number")"
  local pack_path="$(surface_pack_path "$surface")"
  local capture_path="/tmp/dogarea_manual_blocker_status_${surface}_$$"
  render_missing_pack_if_needed "$surface" "$pack_path"
  apply_prefill_if_requested "$surface" "$pack_path"
  local status="$(surface_status_and_capture "$surface" "$pack_path" "$capture_path")"

  printf '== %s ==\n' "$surface"
  printf 'title: %s\n' "$(surface_title "$surface")"
  printf 'issue: #%s (%s)\n' "$issue_number" "$issue_state"
  printf 'related-issues: %s\n' "$(surface_related_issues "$surface")"
  printf 'pack: %s\n' "$pack_path"
  printf 'status: %s\n' "$status"
  printf 'next-render: %s\n' "$(surface_render_command "$surface" "$pack_path")"
  printf 'next-prefill-existing: %s\n' "$(surface_prefill_command "$surface" "$pack_path")"
  if [[ "$status" == "incomplete" && "$apply_prefill" != "1" ]] && surface_has_prefill_gaps "$surface" "$capture_path" && surface_has_missing_prefill_envs "$surface"; then
    printf 'next-prefill-env: %s\n' "$(surface_prefill_env_command "$surface")"
    printf 'next-prefill-bootstrap: %s\n' "$(surface_prefill_bootstrap_command "$surface")"
  fi
  if [[ "$status" == "incomplete" && "$apply_prefill" != "1" ]] && surface_has_prefill_gaps "$surface" "$capture_path"; then
    printf 'next-apply-prefill: %s\n' "$(surface_apply_prefill_status_command "$surface")"
  fi
  printf 'next-validate: %s\n' "$(surface_validate_command "$surface" "$pack_path")"
  printf 'next-render-closure: %s\n' "$(surface_closure_render_command "$surface" "$pack_path")"
  printf 'next-archive: %s\n' "$(surface_archive_command "$surface" "$pack_path")"
  printf 'next-post-closure: %s\n' "$(surface_closure_post_command "$surface" "$issue_number" "$pack_path")"
  if [[ "$surface" == "widget" ]]; then
    printf 'next-post-closure-bundle: %s\n' "$(surface_bundle_post_command "$surface" "$pack_path")"
    surface_simulator_baseline_plain "$surface"
    surface_prefill_resolution_plain "$surface"
  fi
  if [[ "$status" == "incomplete" ]]; then
    surface_prefill_gap_summary_plain "$surface" "$capture_path"
    if surface_has_prefill_gaps "$surface" "$capture_path"; then
      surface_missing_prefill_env_summary_plain "$surface"
    fi
    surface_gap_summary_plain "$surface" "$capture_path"
  fi
  printf '\n'
  rm -f "$capture_path"
}

print_surface_status_markdown() {
  local surface="$1"
  local issue_number="$(surface_issue_number "$surface")"
  local issue_state="$(surface_issue_state "$issue_number")"
  local pack_path="$(surface_pack_path "$surface")"
  local capture_path="/tmp/dogarea_manual_blocker_status_${surface}_$$"
  render_missing_pack_if_needed "$surface" "$pack_path"
  apply_prefill_if_requested "$surface" "$pack_path"
  local status="$(surface_status_and_capture "$surface" "$pack_path" "$capture_path")"

  printf '## %s\n' "$surface"
  printf -- '- Title: %s\n' "$(surface_title "$surface")"
  printf -- '- Primary Issue: [#%s](%s) (`%s`)\n' "$issue_number" "$(surface_issue_url "$issue_number")" "$issue_state"
  if [[ "$surface" == "widget" ]]; then
    printf -- '- Related Issues: [#617](%s), [#692](%s)\n' "$(surface_issue_url 617)" "$(surface_issue_url 692)"
  else
    printf -- '- Related Issues: none\n'
  fi
  printf -- '- Evidence Pack: `%s`\n' "$pack_path"
  printf -- '- Status: `%s`\n\n' "$status"
  printf '### Next Commands\n'
  printf -- '- Render: `%s`\n' "$(surface_render_command "$surface" "$pack_path")"
  printf -- '- Prefill Existing: `%s`\n' "$(surface_prefill_command "$surface" "$pack_path")"
  if [[ "$status" == "incomplete" && "$apply_prefill" != "1" ]] && surface_has_prefill_gaps "$surface" "$capture_path" && surface_has_missing_prefill_envs "$surface"; then
    printf -- '- Print Prefill Env Template: `%s`\n' "$(surface_prefill_env_command "$surface")"
    printf -- '- Bootstrap Prefill In One Shot: `%s`\n' "$(surface_prefill_bootstrap_command "$surface")"
  fi
  if [[ "$status" == "incomplete" && "$apply_prefill" != "1" ]] && surface_has_prefill_gaps "$surface" "$capture_path"; then
    printf -- '- Apply Prefill Then Refresh: `%s`\n' "$(surface_apply_prefill_status_command "$surface")"
  fi
  printf -- '- Validate: `%s`\n' "$(surface_validate_command "$surface" "$pack_path")"
  printf -- '- Render Closure: `%s`\n' "$(surface_closure_render_command "$surface" "$pack_path")"
  printf -- '- Archive: `%s`\n' "$(surface_archive_command "$surface" "$pack_path")"
  printf -- '- Post Closure: `%s`\n' "$(surface_closure_post_command "$surface" "$issue_number" "$pack_path")"
  if [[ "$surface" == "widget" ]]; then
    printf -- '- Post Closure Bundle: `%s`\n' "$(surface_bundle_post_command "$surface" "$pack_path")"
  fi
  printf '\n'
  if [[ "$surface" == "widget" ]]; then
    surface_simulator_baseline_markdown "$surface"
    surface_prefill_resolution_markdown "$surface"
    printf '\n'
  fi
  if [[ "$status" == "incomplete" ]]; then
    surface_gap_summary_markdown "$surface" "$capture_path"
    surface_prefill_gap_summary_markdown "$surface" "$capture_path"
    if surface_has_prefill_gaps "$surface" "$capture_path"; then
      surface_missing_prefill_env_summary_markdown "$surface"
    fi
  fi
  printf '\n'
  rm -f "$capture_path"
}

surfaces=(widget auth-smtp)
[[ -n "$kind_filter" ]] && surfaces=("$kind_filter")

if [[ "$markdown_mode" == "1" ]]; then
  report_path="${output_path:-/tmp/dogarea_manual_blocker_status_report.$$}"
  if [[ -n "$output_path" ]]; then
    mkdir -p "$(dirname "$output_path")"
  fi
  {
    printf '# Manual Blocker Evidence Status Report\n\n'
    printf -- '- Generated At (UTC): %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Repository: dogArea\n'
    printf -- '- Scope: %s\n\n' "${kind_filter:-widget + auth-smtp}"
    for surface in "${surfaces[@]}"; do
      print_surface_status_markdown "$surface"
    done
  } > "$report_path"

  if [[ -n "$output_path" ]]; then
    printf 'WROTE %s\n' "$output_path"
  else
    cat "$report_path"
    rm -f "$report_path"
  fi
else
  for surface in "${surfaces[@]}"; do
    print_surface_status "$surface"
  done
fi
