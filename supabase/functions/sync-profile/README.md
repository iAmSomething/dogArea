# sync-profile Edge Function

## Action
- `sync_profile_stage`
  - `stage=profile`: `profiles` upsert
  - `stage=pet`: `pets` upsert
- `get_profile_snapshot`
  - 현재 인증 사용자 기준 `profiles/pets` 조회

## Request Example
```bash
curl -X POST "$SUPABASE_URL/functions/v1/sync-profile" \
  -H "Authorization: Bearer $SUPABASE_USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "sync_profile_stage",
    "stage": "profile",
    "user_id": "00000000-0000-0000-0000-000000000000",
    "idempotency_key": "profile-00000000-0000-0000-0000-000000000000",
    "payload": {
      "display_name": "dogarea",
      "profile_message": "today walk done"
    }
  }'
```

## Validation
- `pets.age_years`: `null` or `0..30`
- `pets.gender`: `unknown|male|female`
- `pet` stage는 UUID `pet_id`와 non-empty `name` 필수
