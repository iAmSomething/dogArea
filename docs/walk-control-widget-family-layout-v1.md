# Walk Control Widget Family Layout v1

Issue: #614

## Problem

`WalkControlWidget` supported both `systemSmall` and `systemMedium`, but it rendered the same vertical stack for both families. On `systemSmall`, badge, pet context, elapsed timer, status copy, and CTA competed for the same height budget and produced clipping risk.

## Canonical layout split

### systemSmall
- Show only the primary walk state headline.
- Keep exactly one supporting pet line.
- Keep exactly one compact support line.
- Keep exactly one primary CTA.
- Do not show both pet detail and multi-line status message at the same time.
- CTA uses a compact height budget.

### systemMedium
- Keep the walk state headline and pet name block.
- Allow pet detail copy.
- Allow status message copy.
- Keep the primary CTA at standard height.
- Show the latest update time inline with elapsed state.

## Height and overflow policy

- `systemSmall` CTA minimum height: `34`
- `systemMedium` CTA minimum height: `40`
- `systemSmall` CTA title: `lineLimit(1)`
- `systemMedium` CTA title: `lineLimit(2)`
- `systemSmall` support text: `lineLimit(1)`
- `systemMedium` detail/status text: `lineLimit(2)`
- `systemSmall` must never render badge + pet detail + status message as separate stacked text blocks.

## Action-state policy

- `pending`: compact disabled surface in small, standard disabled surface in medium.
- `requiresAppOpen`: one CTA only.
- `failed + retry`: one retry CTA only.
- `noActivePet`: small uses shorter `반려견 확인`, medium keeps `앱에서 반려견 확인`.

## QA points

- `systemSmall` must not clip the CTA bottom edge.
- `systemSmall` must keep the CTA fully inside the widget bounds for idle, walking, pending, failed, and requires-app-open states.
- `systemMedium` must keep pet detail and status message readable without forcing the CTA offscreen.
- Family branching must be explicit through `widgetFamily`.
