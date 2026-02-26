# caricature Edge Function

강아지 원본 프로필 이미지를 받아 OpenAI로 캐리커처를 생성하고, Supabase Storage에 저장한 뒤 `pets.caricature_url`을 업데이트합니다.

## Secrets
아래 시크릿을 프로젝트에 설정해야 합니다.

```bash
npx --yes supabase secrets set \
  OPENAI_API_KEY=... \
  SUPABASE_URL=... \
  SUPABASE_SERVICE_ROLE_KEY=... \
  CARICATURE_BUCKET=caricatures \
  --project-ref ttjiknenynbhbpoqoesq
```

## Deploy
```bash
npx --yes supabase functions deploy caricature --project-ref ttjiknenynbhbpoqoesq
```

## Invoke (example)
```bash
curl -X POST \
  "https://ttjiknenynbhbpoqoesq.functions.supabase.co/caricature" \
  -H "Authorization: Bearer <USER_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "petId": "<uuid>",
    "sourceImagePath": "<user-id>/petProfile.png",
    "prompt": "Turn this dog photo into a clean, cute caricature profile portrait."
  }'
```

## Notes
- 앱에는 `SUPABASE_ANON_KEY`만 사용합니다.
- `SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`는 Edge Function 시크릿으로만 관리합니다.
- OpenAI API 스펙 변경 시 `index.ts` 요청 payload를 최신 스펙에 맞춰 업데이트하세요.
