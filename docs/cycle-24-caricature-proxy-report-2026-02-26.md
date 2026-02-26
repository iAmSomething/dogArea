# Cycle #24 결과 보고서 (2026-02-26)

## 1. 이슈 확인
- 대상 이슈: `#24 [Task] OpenAI 캐리커처 서버 프록시 연동`
- 범위: 요청/응답 스키마 고정, 앱 상태/재시도, 프로필 반영, 관찰성 필드

## 2. 문서화 선반영
- `supabase/functions/caricature/README.md` 신규 작성
  - 요청/응답 스키마(version/requestId 포함)
  - 에러 코드 표준
  - 관찰성 컬럼 정의

## 3. 개발 완료
1. 앱에서 모델 API 키 제거
- `dogArea/Info.plist`의 `OpenAI` 키 삭제
- `dogArea.xcodeproj/project.pbxproj` 내 하드코딩 OpenAI 키 삭제
- `ImageGenerateViewModel`에서 `OpenAIClient` 직접 호출 제거

2. Edge Function 스키마/처리 강화
- `supabase/functions/caricature/index.ts`
  - `version`, `requestId` 스키마 처리
  - 입력 검증(`petId UUID`, source image 필수)
  - 표준 에러코드/메시지 응답
  - 생성 성공 시 `pets.caricature_url/status/provider/style` 반영
  - 실패 시 상태/오류코드 기록

3. 앱 호출 상태(로딩/실패/재시도) 처리
- `ImageGenerateViewModel`
  - `generateImage`, `retryLastRequest` 추가
  - 실패 메시지와 재시도 컨텍스트 유지
- `TextToImageView`
  - 실패 시 `다시 시도` 버튼 제공
  - 생성 중 상태/완료 메시지 제공

4. 생성 결과 URL 프로필 반영
- 공용 `CaricatureEdgeClient` 추가 (`UserdefaultSetting.swift`)
- `SigningViewModel`/`ImageGenerateViewModel` 모두 해당 클라이언트 사용
- `SigningViewModel`에서 랜덤 petId 제거, 저장된 `petInfo.petId` 사용

5. 실패 로그/관찰성 필드
- `supabase/migrations/20260226234500_caricature_jobs_observability_columns.sql` 추가
  - `request_id`, `schema_version`, `source_type`, `error_code`, `provider_used`, `fallback_used`, `latency_ms`, `completed_at`

## 4. 유닛 테스트
- `swift scripts/caricature_proxy_unit_check.swift` -> PASS
- `swift scripts/feature_gate_architecture_unit_check.swift` -> PASS
- `swift scripts/guest_upgrade_ux_unit_check.swift` -> PASS

## 5. 메모
- 워크트리 환경에 `deno`가 없어 Edge Function 타입체크(`deno check`)는 이번 사이클에서 미실행.
