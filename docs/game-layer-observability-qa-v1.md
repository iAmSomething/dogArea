# Game Layer Observability & QA v1

## 1. 목적
시즌/퀘스트/라이벌/날씨 연동 기능의 운영 품질을 단일 기준으로 점검할 수 있도록 공통 이벤트, KPI, 경보 임계치, QA 게이트를 고정한다.

## 2. 범위
- 대상 도메인: `Season`, `Quest`, `Rival`, `Weather`
- 운영 계층: 앱 이벤트, Supabase RPC/배치, 릴리즈 게이트
- 제외: 실시간 PvP 룸 매칭, 공개 소셜 피드

## 3. 공통 이벤트 규약
### 3.1 필수 공통 필드
- `event_name`: snake_case 이벤트 키
- `occurred_at`: epoch seconds(UTC)
- `user_scope`: `guest|member`
- `session_id`: 추적 가능한 세션 키(없으면 `null`)
- `request_id`: 멱등/재처리 추적 키(없으면 `null`)
- `result`: `success|failure|blocked`
- `error_code`: 실패 시 서버/클라이언트 코드

### 3.2 도메인별 필수 이벤트
- Season
- `season_score_applied`
- `season_decay_applied`
- `season_reward_claimed`
- Quest
- `quest_progress_applied`
- `quest_reward_claimed`
- `quest_reroll_applied`
- `quest_claim_duplicate_blocked`
- Rival
- `rival_privacy_opt_in_completed`
- `rival_leaderboard_fetched`
- `rival_privacy_guard_blocked`
- Weather
- `weather_replacement_applied`
- `weather_shield_consumed`
- `weather_feedback_submitted`

## 4. KPI 대시보드 기준
### 4.1 핵심 KPI
| KPI | 정의 | 목표 |
| --- | --- | --- |
| `quest_completion_rate_7d` | 최근 7일 퀘스트 완료율 | `>= 0.35` |
| `quest_claim_duplicate_rate_7d` | 중복 클레임 차단/요청 비율 | `<= 0.005` |
| `season_participation_rate_7d` | 시즌 참여 사용자 비율 | `>= 0.30` |
| `rival_opt_in_rate_7d` | 라이벌 동의 완료율 | `>= 0.25` |
| `weather_replacement_acceptance_rate_7d` | 악천후 치환 퀘스트 수락율 | `>= 0.40` |
| `sync_auth_refresh_failure_rate_24h` | 세션 리프레시 실패율 | `<= 0.01` |

### 4.2 운영 경보(Alerts)
- `quest_claim_duplicate_rate_7d > 0.01`: 중복 클레임 경보(P1)
- `season_participation_rate_7d < 0.20`: 참여율 하락 경보(P2)
- `rival_privacy_guard_blocked` 24h 급증(평균 대비 2배 이상): 프라이버시 정책 경보(P1)
- `weather_feedback_submitted` 24h 급감(평균 대비 50% 이하): 피드백 파이프라인 경보(P2)
- `sync_auth_refresh_failure_rate_24h > 0.03`: 인증 세션 경보(P1)

### 4.3 단일 조회 뷰(운영/QA 공통)
- `public.view_game_layer_kpis_7d`
- 집계 기간:
  - `quest_*`, `season_*`, `rival_*`, `weather_*` 지표는 최근 7일
  - `sync_auth_refresh_failure_rate_24h`는 최근 24시간
- 산식:
  - `quest_completion_rate_7d = quest_reward_claimed / quest_progress_applied`
  - `quest_claim_duplicate_rate_7d = quest_claim_duplicate_blocked / (quest_reward_claimed + quest_claim_duplicate_blocked)`
  - `season_participation_rate_7d = season_participated_users / game_layer_active_users`
  - `rival_opt_in_rate_7d = rival_opt_in_users / rival_touched_users`
  - `weather_replacement_acceptance_rate_7d = weather_replacement_applied / (weather_replacement_applied + weather_shield_consumed)`
  - `sync_auth_refresh_failure_rate_24h = sync_auth_refresh_failed / (sync_auth_refresh_failed + sync_auth_refresh_succeeded)`

## 5. QA 시나리오 게이트
### 5.1 공통 E2E
1. 로그인(이메일) 후 앱 재실행 시 자동 로그인 유지 확인
2. 산책 이벤트 재처리 시 퀘스트 진행도 멱등 반영 확인
3. 동시 클레임 경쟁 요청에서 단일 수령 보장 확인
4. 날씨 치환 적용/미적용 경계값에서 결과 일관성 확인
5. 라이벌 동의/비동의 상태에서 접근 제어 및 로그 적재 확인

### 5.2 릴리즈 블로킹 규칙
- P0: 데이터 소유권 위반, 중복 보상 지급, 인증 세션 붕괴
- P1: KPI 경보 임계치 초과가 24시간 이상 지속
- 배포 전 조건: `ios_pr_check` + 최소 1건의 로그인 포함 UI 스모크

## 6. 운영 런북 연결
- 마이그레이션/운영 SQL: `docs/supabase-migration.md`
- 릴리즈 회귀 게이트: `docs/release-regression-checklist-v1.md`
- 에픽 추적: `#123`, 실행 태스크: `#206`, `#247`

## 7. 변경 관리
- 본 문서 변경 시 `scripts/game_layer_observability_qa_unit_check.swift`를 함께 갱신한다.
- KPI 목표값은 운영 데이터 기반으로 조정하되, 변경 사유를 사이클 리포트에 기록한다.
