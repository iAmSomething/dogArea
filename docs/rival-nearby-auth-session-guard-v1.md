# Rival Nearby Auth Session Guard v1

Date: 2026-03-04
Issue: #277 (`nearby-presence get_hotspots 401 Invalid JWT`)

## Problem Summary

- Rival 탭 폴링(`refreshHotspots`/`refreshLeaderboard`)이 인증 세션 불일치 상태에서도 계속 호출될 수 있었습니다.
- `currentUserId`가 `identity`만으로 계산되면(토큰 세션 없음) 호출이 반복되며 401 로그가 누적될 수 있습니다.

## Code Guard Added

- `RivalTabViewModel.currentUserId`에서 `authSessionStore.currentTokenSession()` 존재를 필수로 확인합니다.
- 401/403 감지 시:
  - 토큰 세션 즉시 삭제 (`clearTokenSession`)
  - 익명 공유 상태 OFF
  - 핫스팟/리더보드 데이터 초기화
  - 사용자 토스트로 재로그인 안내

## Deployment / Env Consistency Check Notes

- `supabase/functions/nearby-presence/index.ts`는 서버 내부에서 `service_role`로 DB 작업을 수행합니다.
- 본 저장소의 `supabase/config.toml`에는 `nearby-presence` 전용 `verify_jwt` override가 없습니다.
  - 따라서 배포 환경 기본값(Edge Function JWT 검증 정책)에 따라 Authorization 헤더 유효성에 영향을 받습니다.
- 운영 점검 시 아래 항목을 확인해야 합니다.
  - 함수 배포 상태: `nearby-presence` latest 배포 여부
  - 프로젝트 JWT/키 정책: 앱에서 사용하는 인증 토큰과 함수 JWT 검증 정책 일치 여부
  - 로그: 401 발생 시 인증 만료/재로그인 플로우로 즉시 수렴하는지

## Verification

- `swift scripts/rival_auth_session_guard_unit_check.swift`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
