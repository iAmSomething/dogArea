# upload-profile-image

Supabase Edge Function for uploading user/pet profile images to Supabase Storage.

## Bucket
- `profiles`

## Request
- Method: `POST`
- Headers:
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`

```json
{
  "ownerId": "user_or_owner_id",
  "imageBase64": "<base64>",
  "imageKind": "user",
  "contentType": "image/jpeg"
}
```

## Response
```json
{
  "ok": true,
  "bucket": "profiles",
  "path": "owner/userProfile.jpeg",
  "publicUrl": "https://<project>.supabase.co/storage/v1/object/public/profiles/owner/userProfile.jpeg"
}
```

## Notes
- max image size: 5MB
- `imageKind`: `user` or `pet`
- uploads are `upsert: true`
- member bearer:
  - `ownerId`는 optional
  - 보내는 경우 `auth.user.id`와 같아야 합니다
  - object path: `<auth.user.id>/userProfile.<ext>` or `<auth.user.id>/petProfile.<ext>`
- anon bearer:
  - `ownerId`는 required
  - `anon-onboarding-*` 임시 namespace만 허용합니다
  - object path: `anon-onboarding/<ownerId>/userProfile.<ext>` or `anon-onboarding/<ownerId>/petProfile.<ext>`

## Error Codes
- `METHOD_NOT_ALLOWED`
- `SERVER_MISCONFIGURED`
- `INVALID_JSON`
- `OWNER_BINDING_UNAVAILABLE`
- `OWNER_ID_REQUIRED`
- `INVALID_OWNER_ID`
- `UNAUTHORIZED_USER_MISMATCH`
- `ANON_OWNER_NAMESPACE_REQUIRED`
- `IMAGE_BASE64_REQUIRED`
- `INVALID_IMAGE_BASE64`
- `INVALID_IMAGE_SIZE`
- `STORAGE_UPLOAD_FAILED`
- `PUBLIC_URL_FAILED`
