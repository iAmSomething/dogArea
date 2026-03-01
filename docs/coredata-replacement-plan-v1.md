# CoreData Replacement Plan v1

## Completed
- Removed CoreData runtime contract and persistence files.
- Replaced Polygon/Area persistence with file-backed cache snapshot.
- Removed `dogArea.xcdatamodeld` source usage from app logic.

## Replacement objects
- `WalkSessionCacheRecord`
- `WalkPointCacheRecord`
- `WalkCacheSnapshot`
- `WalkRepository` / `WalkRepositoryProtocol`

## Data flow
1. `MapViewModel` saves polygon to `WalkRepository`.
2. Repository writes local snapshot immediately.
3. Repository creates `WalkSessionBackfillDTO` and enqueues sync outbox.
4. `SupabaseSyncOutboxTransport` flushes staged payloads to Supabase.

## Rollback
- Disable `ff_supabase_read_v1` to enforce local-read fallback.
- Keep outbox queue; re-enable flag to resume remote sync.

## Validation checklist
- `import CoreData` removed from app targets.
- Map/Home/WalkList/Setting use repository dependency.
- Guest upgrade flow still backfills local walk sessions via outbox.
