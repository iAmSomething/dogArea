# Cycle 168 - Rival Stage2 백엔드 구현 (2026-03-01)

## 1) 이슈
- 대상: #131 `[Task][Rival][Stage 2] 익명 매칭/리더보드 백엔드 구현`

## 2) 구현 범위
### A. Supabase 마이그레이션
- 신규: `supabase/migrations/20260301153000_rival_stage2_leaderboard_backend.sql`

포함 내용:
1. 익명 프로필/가명 테이블
- `rival_alias_profiles`
- 시즌 키 기준 alias/seed 회전

2. 어뷰징 감사 테이블
- `rival_abuse_audit_logs`
- 리더보드 산출 제외 근거 기록

3. 리더보드 API
- `rpc_get_rival_leaderboard(period_type, top_n, now_ts)`
- 기간 타입: day/week/season
- exact 점수 대신 `rival_score_bucket` 기반 구간 점수 반환
- 어뷰징 필터: 최근 14일 `season_score_audit_logs.blocked=true` 사용자 제외 + 감사 로그 upsert

4. 사용자 데이터 권리 경로
- `rpc_export_my_rival_data(requested_user_id, now_ts)`
- `rpc_delete_my_rival_data(requested_user_id, now_ts)`

### B. Edge Function 확장
- 수정: `supabase/functions/rival-league/index.ts`
- 액션 추가:
  - `get_leaderboard`
  - `export_my_data`
  - `delete_my_data`
- 기존 `get_my_league` 유지

### C. 문서/검증
- 신규 문서: `docs/rival-stage2-backend-v1.md`
- 신규 체크: `scripts/rival_stage2_backend_unit_check.swift`
- 체크 파이프라인 연결: `scripts/ios_pr_check.sh`
- README 링크 추가

## 3) 요구사항 매핑
1. 라이벌 풀 생성 규칙
- 기존 #149 구현(`rpc_refresh_rival_leagues`) 기반 유지

2. 익명 프로필/가명 생성 테이블
- 이번 사이클 `rival_alias_profiles` 추가로 충족

3. 격자 단위 비교 집계 파이프라인
- 기존 nearby privacy hard guard(#150) + stage2 리더보드 응답 경로 분리

4. 리더보드 API(일/주/시즌)
- `rpc_get_rival_leaderboard`로 충족

5. 어뷰징 탐지 필터 + 감사 경로
- `season_score_audit_logs.blocked` 연동 제외 + `rival_abuse_audit_logs` 기록으로 충족

6. 사용자 데이터 내보내기/삭제 경로
- export/delete RPC 추가로 충족

## 4) 테스트
1. 단일 체크
- `swift scripts/rival_stage2_backend_unit_check.swift` -> PASS

2. PR 체크
- `DOGAREA_SKIP_BUILD=1 ./scripts/ios_pr_check.sh` -> PASS

## 5) 후속
- DB 반영은 배포 타이밍에 `supabase db push`로 적용.
- 클라이언트(#132)에서 `get_leaderboard/export_my_data/delete_my_data` 액션 연결 예정.
