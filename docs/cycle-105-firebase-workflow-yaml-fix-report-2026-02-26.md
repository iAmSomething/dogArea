# Cycle 105 Report — Firebase Workflow YAML Parse Recovery (2026-02-26)

## 1. Scope
- Issue: #105
- Goal: Recover `.github/workflows/firebase-app-distribution.yml` from YAML parse failure causing `0s` failed runs and `workflow_dispatch` 422 errors.

## 2. Root Cause
- In step `Ensure CI config placeholders`, a heredoc terminator (`CONFIG`) lost indentation inside the YAML `run: |` block.
- This broke workflow parsing before job execution.

## 3. Changes
1. Workflow fix
- Replaced heredoc placeholder generation with `printf`-based file generation in:
  - `.github/workflows/firebase-app-distribution.yml`

2. Regression guard
- Added unit assertion to ensure problematic heredoc pattern is absent:
  - `scripts/firebase_distribution_workflow_unit_check.swift`

3. Runbook update
- Added “YAML stability guard” section explaining why `printf` is required:
  - `docs/github-actions-firebase-distribution.md`

## 4. Verification
- `swift scripts/firebase_distribution_workflow_unit_check.swift`
- `swift scripts/release_regression_checklist_unit_check.swift`
- `swift scripts/swift_stability_unit_check.swift`

## 5. Expected Outcome
- Push-triggered Firebase workflow starts actual jobs (not immediate parse failure).
- `gh workflow run firebase-app-distribution.yml --ref main` no longer returns 422.
