# UserInfo Supabase Sync v1

## 대상 이슈
- #114 User/Pet 확장 필드 Supabase 스키마/동기화 반영

## 목적
- 로컬(UserDefaults) 기준으로만 유지되던 `profileMessage`, `breed`, `ageYears`, `gender`를 Supabase 원격 스키마와 동기화 계약에 반영한다.
- 앱 저장 시점에 profile/pet 스냅샷을 outbox 기반으로 전송 가능하도록 계약을 고정한다.

## 스키마 계약
- `public.profiles`
  - `profile_message text null`
- `public.pets`
  - `breed text null`
  - `age_years int null` (`0..30` 제약)
  - `gender text not null default 'unknown'` (`unknown|male|female`)

## 동기화 계약 (Outbox -> Edge Function)
- endpoint: `POST /functions/v1/sync-profile`
- action: `sync_profile_stage`
- stage:
  - `profile`: 사용자 프로필 스냅샷 upsert
  - `pet`: 반려견 1건 스냅샷 upsert

request body:
```json
{
  "action": "sync_profile_stage",
  "stage": "profile",
  "user_id": "uuid",
  "pet_id": null,
  "idempotency_key": "profile-{user_id}",
  "payload": {
    "display_name": "태훈",
    "profile_image_url": "https://...",
    "profile_message": "오늘도 산책!"
  }
}
```

pet stage payload:
```json
{
  "name": "몽이",
  "photo_url": "https://...",
  "breed": "poodle",
  "age_years": "5",
  "gender": "male",
  "is_active": "true"
}
```

## Outbox 저장 계약
- 키: `sync.profile.outbox.items.v1`
- 상태: `queued|retrying|processing|permanentFailed|completed`
- retry 정책:
  - retryable: `offline|token_expired|server_error|not_configured|unknown`
  - permanent: `schema_mismatch|storage_quota`
- 순서:
  - `profile` 먼저
  - `pet` 이후 (각 pet 개별 멱등키)

## 기본값/백필
- 기존 row의 `gender`가 null/비정상 문자열이면 `unknown`으로 정규화
- 기존 row의 `age_years`가 범위 외 값이면 `null`로 정리
- `breed` 빈 문자열은 `null` 정리

## QA 체크
- [ ] migration 적용 후 기존 row가 제약 위반 없이 유지된다.
- [ ] 앱에서 프로필/반려견 수정 후 outbox에 profile/pet stage가 적재된다.
- [ ] 동일 idempotency key 재전송 시 중복 row 생성 없이 upsert 된다.
- [ ] `get_profile_snapshot` 조회에서 로컬 저장값과 원격 값이 일치한다.
