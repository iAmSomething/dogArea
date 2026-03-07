#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[dogArea-backend] running integration harness structure checks"
swift scripts/supabase_integration_harness_unit_check.swift
swift scripts/backend_contract_versioning_unit_check.swift
swift scripts/backend_edge_observability_unit_check.swift
swift scripts/backend_edge_auth_unification_unit_check.swift
swift scripts/backend_request_id_idempotency_unit_check.swift
swift scripts/backend_scheduler_ops_unit_check.swift
swift scripts/sync_walk_stage_handler_split_unit_check.swift
swift scripts/nearby_presence_handler_split_unit_check.swift

echo "[dogArea-backend] running migration drift / rpc contract checks"
bash scripts/backend_migration_drift_check.sh

if [[ "${DOGAREA_RUN_SUPABASE_SMOKE:-0}" != "1" ]]; then
  echo "[dogArea-backend] DOGAREA_RUN_SUPABASE_SMOKE=1 이 아니므로 실 Supabase smoke matrix는 건너뜁니다."
  echo "[dogArea-backend] run: DOGAREA_RUN_SUPABASE_SMOKE=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/backend_pr_check.sh"
  exit 0
fi

bash scripts/run_supabase_smoke_matrix.sh
