# Walk Control Widget Family Layout v1

Issue: #614

## Problem

`WalkControlWidget` supported both `systemSmall` and `systemMedium`, but it rendered the same vertical stack for both families. On `systemSmall`, badge, pet context, elapsed timer, status copy, and CTA competed for the same height budget and produced clipping risk.

## Canonical layout split

### systemSmall
- Show only the primary walk state headline.
- Keep exactly one supporting pet line.
- Keep exactly one compact support line with widget-only short copy.
- Keep exactly one primary CTA.
- Do not reserve a separate badge row in `systemSmall`; status meaning must collapse into the compact copy itself.
- Do not show raw `statusMessage` or pet detail prose directly.
- Do not show both pet detail and multi-line status message at the same time.
- CTA uses a compact height budget.
- Compact family may omit badges entirely when the headline/support copy already carries the state.

### systemMedium
- Keep the walk state headline and pet name block.
- Allow one canonical detail block only.
- Keep the primary CTA at standard height.
- Show the latest update time inline only while elapsed state is visible.

## Height and overflow policy

- `systemSmall` CTA minimum height: `34`
- `systemMedium` CTA minimum height: `40`
- `systemSmall` CTA title: `lineLimit(1)`
- `systemMedium` CTA title: `lineLimit(2)`
- `systemSmall` support text: `lineLimit(1)`
- `systemMedium` detail/status text: `lineLimit(2)`
- `systemSmall` body spacing must stay at `4pt` so headline/support/detail/CTA can converge without clipping.
- `systemSmall` must never render badge + pet detail + status message as separate stacked text blocks.
- Widget surface must use short family/state-specific copy so the user never sees UI truncation as `...`.

## Action-state policy

- `pending`: compact disabled surface in small, standard disabled surface in medium.
- `requiresAppOpen`: one CTA only.
- `failed + retry`: one retry CTA only.
- `noActivePet`: small uses shorter `반려견 확인`, medium keeps `앱에서 반려견 확인`.
- `systemSmall` state copy must collapse to `headline + optional pet line + optional one-line detail + CTA`.
- `systemMedium` state copy must collapse to `headline + optional pet line + one detail block + optional elapsed row + CTA`.

## QA points

- `systemSmall` must not clip the CTA bottom edge.
- `systemSmall` must keep the CTA fully inside the widget bounds for idle, walking, pending, failed, and requires-app-open states.
- `systemMedium` must keep pet detail and status message readable without forcing the CTA offscreen.
- Family branching must be explicit through `widgetFamily`.
- Smallest supported real device is the acceptance baseline, not preview.
