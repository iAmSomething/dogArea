# Rival Stage2 Backend v1

## 1. 목적
Stage1 정책(#130)을 실제 백엔드 계약으로 연결해 익명 리더보드/가명 프로필/데이터 내보내기·삭제 경로를 제공한다.

연결 이슈:
- Stage2: #131
- 선행: #130, #149, #150

## 2. 구성 요소
1. 가명 프로필 테이블
- `rival_alias_profiles`
- 사용자별 시즌 가명(`alias_code`)과 아바타 시드(`avatar_seed`)를 보관
- 시즌 키 변경 시 자동 회전

2. 어뷰징 감사 테이블
- `rival_abuse_audit_logs`
- 리더보드 산출 시 어뷰징 의심 사용자 제외 근거를 기록
- 현재 v1 필터 기준: `season_score_audit_logs.blocked=true` 최근 14일

3. 리더보드 RPC
- `rpc_get_rival_leaderboard(period_type, top_n, now_ts)`
- 기간 타입: `day | week | season`
- 제품 표현 기준: **일/주/시즌 리더보드**
- exact 점수 대신 **구간 점수(score bucket)**만 응답
- 반환 항목:
  - `rank_position`
  - `user_key` (해시 키)
  - `alias_code` / `avatar_seed`
  - `league` / `effective_league`
  - `score_bucket`
  - `is_me`

4. 사용자 데이터 권리 경로
- `rpc_export_my_rival_data(requested_user_id, now_ts)`
  - 가시성 설정/가명 프로필/리그 이력/감사 로그 내보내기
- `rpc_delete_my_rival_data(requested_user_id, now_ts)`
  - 위치 공유 비활성화 + presence/가명/리그 이력/감사 로그 삭제

5. Edge Function 확장
- `supabase/functions/rival-league`
- 액션:
  - `get_my_league`
  - `get_leaderboard`
  - `export_my_data`
  - `delete_my_data`

## 3. 리더보드 산정 규칙
1. day/week
- `walk_sessions` 기반 활동 점수 집계
- `activity_score = duration_sec/60*duration_weight + area_m2/10000*area_weight`
- 기본 가중치: duration 0.6 / area 0.4 (`rival_league_policies`)

2. season
- `season_user_scores.total_score` 기반 집계
- 최신 시즌(`season_runs`) 우선 선택

3. 어뷰징 필터
- 최근 14일 `season_score_audit_logs.blocked=true` 사용자는 제외
- 제외 사실은 `rival_abuse_audit_logs`에 upsert

## 4. 개인정보 보호
1. 리더보드 응답에서 정밀 위치/원점수 미노출
2. 사용자 식별은 해시 키 + 시즌 가명 조합
3. 데이터 삭제 경로에서 위치 공유 강제 off 후 관련 데이터 정리

## 5. 운영 체크리스트
1. `rpc_get_rival_leaderboard('day'|'week'|'season')` 응답 지연/성능 모니터링
2. `rival_abuse_audit_logs` 적재율 급증 여부 확인
3. 시즌 전환 주차에서 가명 회전 정상 여부 검증
4. export/delete 요청 처리 로그 검증
