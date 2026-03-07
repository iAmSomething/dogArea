# quest-engine Edge Function

퀘스트 Stage2 백엔드 엔진(RPC) 진입점입니다.

## Action
- `issue_quests`
- `ingest_walk_event`
- `claim_reward`
- `transition_status`
- `list_active`

## Request Example
```json
{
  "action": "issue_quests",
  "scope": "daily"
}
```

```json
{
  "action": "ingest_walk_event",
  "request_id": "quest-progress-0001",
  "instance_id": "00000000-0000-0000-0000-000000000000",
  "event_id": "session-uuid:points:42:walk_duration",
  "event_type": "walk_sync_points",
  "delta_value": 12,
  "payload": {
    "walk_session_id": "00000000-0000-0000-0000-000000000000"
  }
}
```

## Response Example
```json
{
  "progress": {
    "quest_instance_id": "00000000-0000-0000-0000-000000000000",
    "idempotent": false,
    "status": "completed"
  }
}
```


## Request Key Rules
- canonical correlation key: `request_id`
- canonical idempotency key: `idempotency_key`
- quest progress ledger key: `event_id`
- legacy alias `requestId` / `eventId` / `instanceId` / `target_instance_id` are still accepted
