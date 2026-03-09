# Walk Control Widget Timer Refresh v1

Issue: #615

## Problem

- `WalkControlWidget` rendered elapsed time as a frozen string.
- timeline policy refreshed once after `15m`, so a running walk could look stale.
- walk widget reload signature ignored the timer axis, so app-side snapshot saves could skip `reloadTimelines`.

## Canonical Rules

1. While `isWalking == true`, the widget elapsed time must render with timer-style text from the walk start reference.
2. While `isWalking == false`, elapsed time stays frozen text.
3. `WalkWidgetSnapshot` must persist `startedAt` so widget rendering does not depend on repeated foreground sync writes.
4. `timelineReloadSignature` must include the timer axis through:
   - `startedAt`
   - `elapsed minute bucket`
   - `updatedAt minute bucket`
5. The signature must not use raw `elapsedSeconds` per save, to avoid 5-second reload churn.

## Timeline Policy

- active walk: next refresh after `60s`
- pending action: next refresh after `30s`
- requires app open: next refresh after `120s`
- idle state: next refresh after `15m`

## Surface Contract

- `WalkControlWidget` home/lock widget follows the same timer interpretation for all supported families.
- action state copy continues to override status copy, but timer rendering must stay independent from action badge presentation.

## Forbidden

- no fallback to fixed elapsed strings while walking
- no raw `elapsedSeconds` signature that reloads every app-side save
- no `reloadAllTimelines()` workaround
