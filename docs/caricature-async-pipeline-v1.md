# Caricature Async Pipeline v1

## 1. 목적
가입 플로우를 블로킹하지 않고, 반려견 원본 사진 업로드 후 캐리커처 생성은 비동기 백그라운드 파이프라인으로 처리한다.

연결 이슈:
- 구현: #44

## 2. 가입 UX 계약
1. 원본 반려견 사진 업로드(Firebase/Supabase 저장소)
2. 사용자 가입 즉시 완료 처리
3. 캐리커처 상태:
- `queued` -> `processing` -> `ready | failed`
4. 실패 시 가입 자체는 성공 상태 유지
5. 완료 시 반려견 프로필 이미지를 캐리커처 URL로 갱신

## 3. DB 계약

### 3.1 `pets` 컬럼
- `caricature_status text` (`queued|processing|ready|failed`)
- `caricature_provider text`
- `caricature_style text`
- `caricature_url text`

### 3.2 `caricature_jobs` 테이블
- `id uuid pk`
- `user_id uuid`
- `pet_id uuid`
- `style text`
- `provider_chain text`
- `status text`
- `error_message text`
- `retry_count int`
- `created_at timestamptz`
- `updated_at timestamptz`

상태 전이:
- `queued -> processing -> ready | failed`

## 4. Edge Function 계약
엔드포인트:
- `POST /functions/v1/caricature`

요청:
```json
{
  "petId": "uuid",
  "sourceImagePath": "optional/storage/path.jpg",
  "sourceImageUrl": "optional/https-url",
  "style": "cute_cartoon",
  "providerHint": "auto",
  "requestId": "uuid"
}
```

라우팅:
- 기본: Gemini 우선
- 실패 시: OpenAI 폴백
- timeout 25초 / provider당 최대 2회 재시도

응답:
- 성공: `status=ready`, `caricatureUrl`, `provider`, `jobId`
- 실패: `status=failed`, `errorCode`, `jobId`

## 5. iOS 앱 계약
- 가입 ViewModel은 원본 업로드/로컬 저장 완료 후 바로 `loading=.success`
- 캐리커처 요청은 detached task로 실행
- 로컬 사용자 저장소(UserDefaults)에도 상태를 반영:
  - queued (가입 직후)
  - processing (요청 시작)
  - ready + caricatureURL/provider (성공)
  - failed (실패)

## 6. 검증 체크리스트
- [ ] 캐리커처 실패 시 가입 플로우 차단 없음
- [ ] 상태 전이(`queued -> processing -> ready/failed`) 추적 가능
- [ ] Edge Function이 provider fallback 경로를 가짐
- [ ] ready 시 프로필 화면에서 캐리커처 URL 우선 표시
