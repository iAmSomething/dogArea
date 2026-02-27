# Rival Fair League Matching v1 (Issue #149)

## 1. 목표
최근 14일 활동량 기준으로 라이트/미드/하드코어 리그를 주간 단위로 배정해 공정한 비교 풀을 구성한다.

## 2. 정책
- 산정 구간: 최근 `14일`
- 반영 주기: `주 1회` 스냅샷
- 리그 구간:
  - `onboarding`: 신규/저활동 보호 구간
  - `light`: 하위 활동량 밴드
  - `mid`: 중간 활동량 밴드
  - `hardcore`: 상위 활동량 밴드
- 표본 부족 fallback:
  - 최소 표본(`min_sample_per_league`) 미달 시 인접 리그로 임시 병합(`effective_league`)

## 3. 활동량 스코어
기본식:
- `activity_score = (duration_min * duration_weight) + (area_m2 / 10000 * area_weight)`

기본 파라미터:
- `duration_weight = 0.6`
- `area_weight = 0.4`

## 4. 스키마
- `rival_league_policies`: 운영 파라미터
- `rival_league_assignments`: 사용자 최신 리그 스냅샷
- `rival_league_history`: 승격/강등/병합 이력
- `view_rival_league_distribution_current`: 최신 분포 모니터링 뷰

## 5. RPC/Edge Function
- `rpc_refresh_rival_leagues(target_snapshot_week_start, now_ts)`
  - 주간 리그 재산정(운영/배치 경로)
- `rpc_get_my_rival_league(requested_user_id, now_ts)`
  - 본인 리그/병합 여부/안내 메시지 조회
- `supabase/functions/rival-league`
  - `get_my_league` 액션으로 앱 조회 경로 제공

## 6. UX 데이터 계약
앱은 다음 값을 기반으로 안내 문구를 표시한다.
- `league`
- `effective_league`
- `fallback_applied`
- `fallback_reason`
- `guidance_message`

## 7. 검증 체크리스트
- [ ] 14일 활동량 경계값에서 light/mid/hardcore 분기가 안정적으로 계산
- [ ] 주간 스냅샷 갱신 시 동일 주간 내 결과가 흔들리지 않음
- [ ] 표본 부족 리그는 `effective_league`로 인접 병합 처리
- [ ] 리그 변경 시 `rival_league_history`에 이력 누락 없이 기록
