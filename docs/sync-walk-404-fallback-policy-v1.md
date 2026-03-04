# Sync-Walk 404 Fallback Policy v1

Date: 2026-03-04  
Issue: #278 (`sync-walk` function 404)

## Problem

- 일부 환경에서 `functions/v1/sync-walk` 호출이 404로 응답했습니다.
- 기존 정책은 `not_configured`를 retryable로 분류해, 동기화 큐가 같은 실패를 반복할 수 있었습니다.

## Client Policy Updates

1. Function route fallback
- primary route: `sync-walk`
- legacy route fallback: `sync_walk` (primary가 404일 때 1회 재시도)

2. 404 retry policy hardening
- `sync-walk` 404는 `permanent(.notConfigured)`로 처리
- 함수 비가용 쿨다운(10분) 동안 재호출을 차단해 요청 폭주를 방지

3. Outbox drain behavior
- `notConfigured` 영구실패는 현재 flush 사이클에서 다음 stage까지 연속 처리
- 결과적으로 pending이 장시간 남아 반복 재시도되는 상태를 줄임

4. User-facing fallback copy
- 지도 동기화 상태: `서버 기능 미배포(404)`
- 홈 이관 카드: `동기화 서버 기능이 아직 준비되지 않았어요(404).`

## Ops Checklist

- Supabase Edge Function 배포 확인
  - canonical: `sync-walk`
  - legacy fallback 필요 시 `sync_walk` 라우트 여부 확인
- 프로젝트 함수 JWT/환경변수 정책 점검
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - 함수별 secret(`SUPABASE_SERVICE_ROLE_KEY`)
- 배포 후 앱에서 404가 사라지면 fallback은 자동으로 성공 라우트에 수렴

## Validation

- `swift scripts/sync_walk_404_policy_unit_check.swift`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
