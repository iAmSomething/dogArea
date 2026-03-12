#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/auth_smtp_evidence_bundle.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/render_manual_evidence_pack.sh <widget|auth-smtp> [--write] [--output <path>]

Examples:
  bash scripts/render_manual_evidence_pack.sh widget
  bash scripts/render_manual_evidence_pack.sh widget --write
  bash scripts/render_manual_evidence_pack.sh auth-smtp --output .codex_tmp/auth-smtp-evidence
USAGE
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

render_widget_overview() {
  cat <<'OVERVIEW'
# Widget Real-Device Evidence Pack v2

- Related issues: #408, #617, #692, #731
- Runbooks:
  - `docs/widget-action-real-device-evidence-runbook-v1.md`
  - `docs/widget-family-real-device-evidence-runbook-v1.md`
- Validation matrices:
  - `docs/widget-action-real-device-validation-matrix-v1.md`
  - `docs/widget-family-real-device-validation-matrix-v1.md`
- Closure checklist:
  - `docs/widget-action-closure-checklist-v1.md`
- Generated directory layout:
  - `assets/action/`
  - `assets/layout/`
  - `action/WD-001.md` ... `action/WD-008.md`
  - `layout/WL-001.md` ... `layout/WL-008.md`
  - `README.md`

Use `--write` or `--output <dir>` to materialize the bundle skeleton.
OVERVIEW
}

widget_action_file_content() {
  local case_id="$1"
  local family="$2"
  local app_state="$3"
  local auth_state="$4"
  local route="$5"
  local expected="$6"
  local template
  template="$(cat docs/widget-action-real-device-evidence-template-v1.md)"
  printf '%s' "$template" \
    | sed "s#^- Widget Family:#- Widget Family: ${family}#" \
    | sed "s#^- Case ID:#- Case ID: ${case_id}#" \
    | sed "s#^- 앱 상태:#- 앱 상태: ${app_state}#" \
    | sed "s#^- 인증 상태:#- 인증 상태: ${auth_state}#" \
    | sed "s#^- Action Route:#- Action Route: ${route}#" \
    | sed "s#^- Expected Result:#- Expected Result: ${expected}#" \
    | sed "s#^- \`step-1\`: assets/action/<case-id>-step-1.png#- \`step-1\`: assets/action/${case_id}-step-1.png#" \
    | sed "s#^- \`step-2\`: assets/action/<case-id>-step-2.png#- \`step-2\`: assets/action/${case_id}-step-2.png#"
}

widget_layout_file_content() {
  local case_id="$1"
  local surface="$2"
  local family="$3"
  local covered_states="$4"
  local headline_policy="$5"
  local detail_policy="$6"
  local badge_budget="$7"
  local cta_rule="$8"
  local metric_rule="$9"
  local compact_rule="${10}"
  local expected="${11}"
  local template
  template="$(cat docs/widget-family-real-device-evidence-template-v1.md)"
  printf '%s' "$template" \
    | sed "s#^- Widget Surface:#- Widget Surface: ${surface}#" \
    | sed "s#^- Widget Family:#- Widget Family: ${family}#" \
    | sed "s#^- Case ID:#- Case ID: ${case_id}#" \
    | sed "s#^- Covered States:#- Covered States: ${covered_states}#" \
    | sed "s#^- Headline Policy:#- Headline Policy: ${headline_policy}#" \
    | sed "s#^- Detail Policy:#- Detail Policy: ${detail_policy}#" \
    | sed "s#^- Badge Budget:#- Badge Budget: ${badge_budget}#" \
    | sed "s#^- CTA Height Rule:#- CTA Height Rule: ${cta_rule}#" \
    | sed "s#^- Metric Tile Rule:#- Metric Tile Rule: ${metric_rule}#" \
    | sed "s#^- Compact Formatting Rule:#- Compact Formatting Rule: ${compact_rule}#" \
    | sed "s#^- Expected Result:#- Expected Result: ${expected}#" \
    | sed "s#^- \`step-1\`: assets/layout/<case-id>-step-1.png#- \`step-1\`: assets/layout/${case_id}-step-1.png#" \
    | sed "s#^- \`step-2\`: assets/layout/<case-id>-step-2.png#- \`step-2\`: assets/layout/${case_id}-step-2.png#"
}

write_widget_bundle() {
  local dir="$1"
  mkdir -p "$dir/action" "$dir/layout" "$dir/assets/action" "$dir/assets/layout"

  cat > "$dir/README.md" <<'README'
# Widget Real-Device Evidence Pack v2

- Related issues: #408, #617, #692, #731
- Action matrix: `docs/widget-action-real-device-validation-matrix-v1.md`
- Layout matrix: `docs/widget-family-real-device-validation-matrix-v1.md`
- Action runbook: `docs/widget-action-real-device-evidence-runbook-v1.md`
- Layout runbook: `docs/widget-family-real-device-evidence-runbook-v1.md`
- Closure checklist: `docs/widget-action-closure-checklist-v1.md`

## Action Cases
- assets/action/
- action/WD-001.md
- action/WD-002.md
- action/WD-003.md
- action/WD-004.md
- action/WD-005.md
- action/WD-006.md
- action/WD-007.md
- action/WD-008.md

## Layout Cases
- assets/layout/
- layout/WL-001.md
- layout/WL-002.md
- layout/WL-003.md
- layout/WL-004.md
- layout/WL-005.md
- layout/WL-006.md
- layout/WL-007.md
- layout/WL-008.md
README

  cat > "$dir/assets/README.md" <<'README'
# Widget Real-Device Evidence Assets

- `action/WD-001-step-1.png` ... `action/WD-008-step-2.png`
- `layout/WL-001-step-1.png` ... `layout/WL-008-step-2.png`
README

  widget_action_file_content "WD-001" "systemSmall" "cold start" "로그인" "open_rival_tab" "라이벌 탭으로 직접 진입하고 기본 상태가 보인다." > "$dir/action/WD-001.md"
  widget_action_file_content "WD-002" "systemSmall" "cold start" "로그인" "open_hotspot_broad" "라이벌 탭이 3km preset 문맥으로 열린다." > "$dir/action/WD-002.md"
  widget_action_file_content "WD-003" "systemMedium" "background" "로그인" "open_quest_detail" "홈 퀘스트 카드 위치로 이동하고 상세 배너가 보인다." > "$dir/action/WD-003.md"
  widget_action_file_content "WD-004" "systemMedium" "foreground" "로그인" "open_quest_recovery" "홈 퀘스트 카드 위치로 이동하고 recovery 배너가 보인다." > "$dir/action/WD-004.md"
  widget_action_file_content "WD-005" "systemMedium" "cold start" "로그인" "open_territory_goal" "목표 상세 화면으로 직접 진입하고 탭바는 숨겨진다." > "$dir/action/WD-005.md"
  widget_action_file_content "WD-006" "systemSmall" "cold start" "로그인" "walk_start" "앱 세션이 위젯 start 요청을 소비하고 walking 상태로 수렴한다." > "$dir/action/WD-006.md"
  widget_action_file_content "WD-007" "systemSmall" "foreground" "로그인" "walk_end" "앱 세션이 종료 요청을 소비하고 위젯/Live Activity 상태가 종료로 수렴한다." > "$dir/action/WD-007.md"
  widget_action_file_content "WD-008" "systemSmall" "cold start" "로그아웃" "walk_start" "즉시 시작하지 않고 auth overlay 또는 로그인 진입으로 defer 된다." > "$dir/action/WD-008.md"

  widget_layout_file_content "WL-001" "WalkControlWidget" "systemSmall" "idle, pending, failed, requiresAppOpen" "headline 2 lines max" "detail 1 line max" "badge 1 + state chip 1" "CTA 44-52pt" "single metric strip" "compact CTA copy on overflow" "CTA와 상태 문구가 위젯 경계 안에서 수렴한다." > "$dir/layout/WL-001.md"
  widget_layout_file_content "WL-002" "WalkControlWidget" "systemMedium" "walking, ended, succeeded" "headline 2 lines max" "detail 2 lines max" "badge 2 max" "CTA 44-56pt" "metric strip with stable height" "compact status copy on overflow" "진행 상태와 종료 상태가 CTA와 metric strip을 밀어내지 않는다." > "$dir/layout/WL-002.md"
  widget_layout_file_content "WL-003" "TerritoryStatusWidget" "systemSmall" "guestLocked, emptyData" "headline 2 lines max" "detail 1 line max" "badge 1 max" "CTA hidden or 44pt" "no metric tile in small" "compact goal summary fallback" "headline/detail/badge가 2단 정보 구조 안에서 잘리지 않는다." > "$dir/layout/WL-003.md"
  widget_layout_file_content "WL-004" "TerritoryStatusWidget" "systemMedium" "memberReady, offlineCached, syncDelayed" "headline 2 lines max" "detail 2 lines max" "badge 2 max" "CTA 44-52pt" "two-column metric tile stable" "compact area/unit formatting" "다음 목표/현재 목표/보조 문구가 compact fallback으로 수렴한다." > "$dir/layout/WL-004.md"
  widget_layout_file_content "WL-005" "QuestRivalStatusWidget" "systemSmall" "guestLocked, claimFailed" "headline 2 lines max" "detail 1 line max" "badge 1 max" "CTA 44-52pt" "single metric emphasis" "compact result label fallback" "headline과 CTA가 겹치지 않고 실패 문구가 의미를 유지한다." > "$dir/layout/WL-005.md"
  widget_layout_file_content "WL-006" "QuestRivalStatusWidget" "systemMedium" "memberReady, claimInFlight, claimSucceeded" "headline 2 lines max" "detail 2 lines max" "badge 2 max" "CTA 44-56pt" "metric tile + reward summary stable" "compact reward text fallback" "보상/라이벌 문맥이 metric tile과 충돌하지 않는다." > "$dir/layout/WL-006.md"
  widget_layout_file_content "WL-007" "HotspotStatusWidget" "systemSmall" "guestLocked, privacyGuarded" "headline 2 lines max" "detail 1 line max" "badge 1 max" "CTA 44-52pt" "single metric emphasis" "compact privacy note fallback" "privacy 가드 문구와 CTA가 프레임 밖으로 나가지 않는다." > "$dir/layout/WL-007.md"
  widget_layout_file_content "WL-008" "HotspotStatusWidget" "systemMedium" "memberReady, offlineCached, syncDelayed" "headline 2 lines max" "detail 2 lines max" "badge 2 max" "CTA 44-56pt" "radius + status strip stable" "compact distance formatting" "반경/상태/보조 문구가 family budget 안에서 수렴한다." > "$dir/layout/WL-008.md"
}

case "$kind" in
  widget)
    default_output_path=".codex_tmp/widget-real-device-evidence"
    if [[ -z "$output_path" && "$write_mode" == "1" ]]; then
      output_path="$default_output_path"
    fi
    if [[ -n "$output_path" ]]; then
      rm -rf "$output_path"
      write_widget_bundle "$output_path"
      printf 'WROTE %s\n' "$output_path"
    else
      render_widget_overview
    fi
    ;;
  auth-smtp)
    default_output_path="$(auth_smtp_bundle_default_path)"
    if [[ -z "$output_path" && "$write_mode" == "1" ]]; then
      output_path="$default_output_path"
    fi
    if [[ -n "$output_path" ]]; then
      rm -rf "$output_path"
      auth_smtp_bundle_write "$output_path"
      printf 'WROTE %s\n' "$output_path"
    else
      auth_smtp_bundle_render_overview
    fi
    ;;
esac
