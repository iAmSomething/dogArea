# Caricature Edge Function Contract (v2026-02-26.v1)

## Endpoint
- `POST /functions/v1/caricature`

## Purpose
- Generate a dog profile caricature image via provider router (Gemini -> OpenAI fallback).
- Save result to Supabase Storage (`caricatures` bucket).
- Reflect result into `pets.caricature_url` and `pets.caricature_status`.

## Request Schema
```json
{
  "version": "2026-02-26.v1",
  "requestId": "uuid-string",
  "petId": "uuid-string",
  "userId": "uuid-string-optional",
  "sourceImagePath": "profiles/path.jpg",
  "sourceImageUrl": "https://...",
  "style": "cute_cartoon",
  "providerHint": "auto"
}
```

Rules:
- `petId` is required (UUID).
- `sourceImagePath` or `sourceImageUrl` must be provided.
- `style` supports:
  - `cute_cartoon`
  - `line_illustration`
  - `watercolor`
- `providerHint` supports `auto|gemini|openai`.

## Success Response
```json
{
  "version": "2026-02-26.v1",
  "requestId": "uuid-string",
  "jobId": "uuid-string",
  "petId": "uuid-string",
  "status": "ready",
  "provider": "gemini",
  "fallbackUsed": false,
  "caricaturePath": "<user-id>/<pet-id>/<job-id>.png",
  "caricatureUrl": "https://..."
}
```

## Error Response
```json
{
  "errorCode": "SOURCE_IMAGE_NOT_FOUND",
  "message": "source image is unavailable",
  "version": "2026-02-26.v1",
  "requestId": "uuid-string",
  "jobId": "uuid-string"
}
```

## Error Codes
- `METHOD_NOT_ALLOWED`
- `UNAUTHORIZED`
- `INVALID_REQUEST`
- `SOURCE_IMAGE_NOT_FOUND`
- `ALL_PROVIDERS_FAILED`
- `STORAGE_UPLOAD_FAILED`
- `DB_UPDATE_FAILED`
- `SERVER_MISCONFIGURED`

## Observability Fields (`caricature_jobs`)
- `request_id`
- `schema_version`
- `source_type` (`url|path`)
- `error_code`
- `provider_used`
- `fallback_used`
- `latency_ms`
- `completed_at`

## Security
- Model keys (`OPENAI_API_KEY`, `GEMINI_API_KEY`) are Edge Function secrets only.
- App binary must not contain model provider keys.
