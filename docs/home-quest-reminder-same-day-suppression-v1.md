# Home Quest Reminder Same-Day Suppression v1

## Goal
- Keep the existing `퀘스트 리마인드` toggle UX.
- Suppress the same-day `20:00` reminder when the user already saved at least one walk record on that local day.
- Resume the reminder normally on the next local day.

## Rules
- Reminder evaluation is `user-wide`, not selected-pet scoped.
- Only saved walk records count. Started-only or discarded sessions do not count.
- Local day boundaries follow `Calendar.autoupdatingCurrent` and `TimeZone.autoupdatingCurrent`.
- Internal policy stays implicit to the user. The toggle still reads as a daily reminder setting.

## Scheduling Policy
- Replace the repeating trigger with a `one-shot` local notification.
- On each resync:
  - if a saved walk exists on the current local day, schedule the next reminder for tomorrow `20:00`
  - otherwise, schedule today `20:00` when still upcoming
  - otherwise, schedule tomorrow `20:00`
- Automatic resync runs without prompting for notification authorization.
- Manual toggle changes keep the existing permission prompt behavior.

## Resync Triggers
- initial load
- visible reentry
- manual refresh
- app resume
- local day change / timezone change
- toggle on/off

## Implementation Notes
- Home builds the scheduling context from `walkRepository.fetchPolygons()` so the decision uses the latest saved walk records.
- The reminder request identifier stays stable and pending/delivered requests are replaced on each resync.
