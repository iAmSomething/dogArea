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
- object path: `<ownerId>/userProfile.<ext>` or `<ownerId>/petProfile.<ext>`

## Error Codes
- `METHOD_NOT_ALLOWED`
- `SERVER_MISCONFIGURED`
- `INVALID_JSON`
- `OWNER_ID_REQUIRED`
- `INVALID_OWNER_ID`
- `IMAGE_BASE64_REQUIRED`
- `INVALID_IMAGE_BASE64`
- `INVALID_IMAGE_SIZE`
- `STORAGE_UPLOAD_FAILED`
- `PUBLIC_URL_FAILED`
