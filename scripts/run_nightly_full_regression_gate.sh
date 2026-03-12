#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${DOGAREA_NIGHTLY_ARTIFACT_DIR:-$ROOT_DIR/.artifacts/nightly-full-regression}"
REPORT_DIR="$ARTIFACT_DIR/reports"
LOG_DIR="$ARTIFACT_DIR/logs"
EVIDENCE_DIR="$ARTIFACT_DIR/evidence"
SUMMARY_PATH="$REPORT_DIR/nightly-full-regression-summary.md"
MANUAL_STATUS_PATH="$REPORT_DIR/manual-blocker-status.txt"
BACKEND_LOG_PATH="$LOG_DIR/backend-pr-check.log"
AUTH_SMOKE_LOG_PATH="$LOG_DIR/auth-member-401-smoke.log"
DOC_LOG_PATH="$LOG_DIR/nightly-doc-contracts.log"

mkdir -p "$REPORT_DIR" "$LOG_DIR" "$EVIDENCE_DIR"
cd "$ROOT_DIR"

extract_surface_status() {
  local surface="$1"
  local file="$2"
  awk -v target="== ${surface} ==" '
    $0 == target { in_block=1; next }
    /^== / && in_block { exit }
    in_block && /^status: / { print $2; exit }
  ' "$file"
}

render_summary() {
  local nf003_status="$1"
  local nf003_evidence="$2"
  local nf003_note="$3"
  local widget_status="$4"
  local widget_axis_status="HOLD"
  local widget_evidence='RD-004 + evidence/widget-real-device-evidence/'
  local widget_note='Real-device widget transition evidence pending'

  if [[ "$widget_status" == "complete" ]]; then
    widget_axis_status="PASS"
    widget_note='Widget evidence pack is complete and closure-ready'
  elif [[ "$widget_status" == "incomplete" ]]; then
    widget_note='Widget evidence pack exists but validator is still failing'
  fi

  cat > "$SUMMARY_PATH" <<EOF_SUMMARY
# Nightly Full Regression Gate Report

- Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Runner: scripts/run_nightly_full_regression_gate.sh
- Artifact Root: ${ARTIFACT_DIR#"$ROOT_DIR"/}

## Summary
| Axis | Status | Retry | Real Device Evidence | Bucket |
| --- | --- | --- | --- | --- |
| NF-001 | HOLD | 0 | RD-001 | walk_long_session |
| NF-002 | HOLD | 0 | RD-002 | offline_recovery |
| NF-003 | ${nf003_status} | 0 | ${nf003_evidence} | nearby_presence_recovery |
| NF-004 | ${widget_axis_status} | 0 | ${widget_evidence} | widget_state_transition |
| NF-005 | HOLD | 0 | RD-005, RD-006 | watch_queue_sync |

## Detail
- NF-001: Long walk session remains a real-device evidence track. Use docs/release-real-device-evidence-matrix-v1.md and collect RD-001.
- NF-002: Offline recovery remains a real-device evidence track. Use docs/release-real-device-evidence-matrix-v1.md and collect RD-002.
- NF-003: ${nf003_note}
- NF-004: ${widget_note}
- NF-005: Watch queue/sync remains a real-device evidence track. Use docs/release-real-device-evidence-matrix-v1.md and collect RD-005, RD-006.

## Artifacts
- reports/manual-blocker-status.txt
- evidence/widget-real-device-evidence/
- evidence/auth-smtp-evidence/
- logs/backend-pr-check.log
- logs/auth-member-401-smoke.log
EOF_SUMMARY
}

echo "[NightlyGate] Validate docs/contracts"
{
  swift scripts/nightly_full_regression_gate_unit_check.swift
  swift scripts/manual_blocker_evidence_status_unit_check.swift
  swift scripts/manual_evidence_validator_unit_check.swift
} | tee "$DOC_LOG_PATH"

echo "[NightlyGate] Render blocker evidence status"
bash scripts/manual_blocker_evidence_status.sh --write-missing | tee "$MANUAL_STATUS_PATH"

if [[ -d ".codex_tmp/widget-real-device-evidence" ]]; then
  rm -rf "$EVIDENCE_DIR/widget-real-device-evidence"
  cp -R ".codex_tmp/widget-real-device-evidence" "$EVIDENCE_DIR/widget-real-device-evidence"
fi
if [[ -d ".codex_tmp/auth-smtp-evidence" ]]; then
  rm -rf "$EVIDENCE_DIR/auth-smtp-evidence"
  cp -R ".codex_tmp/auth-smtp-evidence" "$EVIDENCE_DIR/auth-smtp-evidence"
fi

widget_status="$(extract_surface_status widget "$MANUAL_STATUS_PATH")"

nf003_status="HOLD"
nf003_evidence='`reports/manual-blocker-status.txt` + `logs/backend-pr-check.log`'
nf003_note='Live backend smoke skipped because DOGAREA_TEST_EMAIL/DOGAREA_TEST_PASSWORD are not set'

echo "[NightlyGate] Run backend baseline checks"
if bash scripts/backend_pr_check.sh > >(tee "$BACKEND_LOG_PATH") 2>&1; then
  nf003_note='backend_pr_check baseline passed; live member smoke not executed'
else
  nf003_status='FAIL'
  nf003_evidence='`logs/backend-pr-check.log`'
  nf003_note='backend_pr_check failed before live recovery verification'
fi

if [[ "$nf003_status" != "FAIL" && -n "${DOGAREA_TEST_EMAIL:-}" && -n "${DOGAREA_TEST_PASSWORD:-}" ]]; then
  echo "[NightlyGate] Run member auth + nearby live smoke"
  if DOGAREA_AUTH_SMOKE_ITERATIONS="${DOGAREA_AUTH_SMOKE_ITERATIONS:-1}" bash scripts/auth_member_401_smoke_check.sh > >(tee "$AUTH_SMOKE_LOG_PATH") 2>&1; then
    nf003_status='PASS'
    nf003_evidence='`logs/backend-pr-check.log`, `logs/auth-member-401-smoke.log`'
    nf003_note='backend baseline and live member auth/nearby smoke both passed'
  else
    nf003_status='FAIL'
    nf003_evidence='`logs/auth-member-401-smoke.log`'
    nf003_note='member auth + nearby smoke failed'
  fi
fi

render_summary "$nf003_status" "$nf003_evidence" "$nf003_note" "$widget_status"

if [[ "$nf003_status" == "FAIL" ]]; then
  echo "[NightlyGate] FAIL: NF-003 backend/live smoke axis failed"
  exit 1
fi

echo "[NightlyGate] Done"
echo "[NightlyGate] Summary: $SUMMARY_PATH"
