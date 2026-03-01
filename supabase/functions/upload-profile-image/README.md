# upload-profile-image

Supabase Edge Function for uploading user/pet profile images to Supabase Storage.

## Bucket
- `profiles`

## Request
- Method: `POST`
- Headers:
  - `Authorization: Bearer <token>` (currently app sends anon key bearer)
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
