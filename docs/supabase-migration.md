# Supabase Migration & Ops Verification v1

## 1. 목적
`profiles/pets/walk_sessions/walk_points/area_milestones/walk_session_pets`와 Storage 정책을 운영 기준으로 검증하기 위한 실행 절차/SQL 세트를 고정한다.

연계 운영 문서:
- `docs/backend-scheduler-ops-standard-v1.md`

연결 이슈:
- #22 `[Task] Supabase 스키마/RLS/Storage 운영 고도화`

## 2. Migration 상태 동기화

### 2.1 로컬 상태
```bash
npx --yes supabase migration list --local
```

### 2.2 원격(linked) 상태
```bash
npx --yes supabase migration list --linked
```

### 2.3 일치 조건
- 로컬 최신 migration 파일이 원격에 동일 순서로 적용되어야 한다.
- 신규 migration 추가 시 `db push --linked` 이후 다시 `migration list --linked`로 확인한다.

```bash
npx --yes supabase db push --linked --dry-run
npx --yes supabase db push --linked
npx --yes supabase migration list --linked
```

## 3. RLS 교차 계정 차단 검증 SQL

사전 준비:
- 테스트 유저 UUID
  - `:user_a_uuid`
  - `:user_b_uuid`
- 테스트용 세션 UUID: `:walk_session_uuid`

### 3.1 User A 컨텍스트
```sql
set local role authenticated;
set local "request.jwt.claim.sub" = ':user_a_uuid';

select id, owner_user_id
from public.walk_sessions
where owner_user_id = auth.uid()
limit 5;
```
기대값: User A 데이터만 조회된다.

### 3.2 User B로 A 데이터 접근 시도
```sql
set local role authenticated;
set local "request.jwt.claim.sub" = ':user_b_uuid';

select id, owner_user_id
from public.walk_sessions
where id = ':walk_session_uuid'::uuid;
```
기대값: 결과 0건(또는 정책 위반).

### 3.3 User B가 A 세션에 포인트 쓰기 시도
```sql
set local role authenticated;
set local "request.jwt.claim.sub" = ':user_b_uuid';

insert into public.walk_points (walk_session_id, seq_no, lat, lng, recorded_at)
values (':walk_session_uuid'::uuid, 9999, 37.5, 127.0, now());
```
기대값: `walk_points_owner_all` 정책으로 차단된다.

## 4. Storage 정책 검증

버킷:
- `profiles`
- `caricatures`
- `walk-maps`

검증 규칙:
- 객체 경로 첫 세그먼트가 `auth.uid()`와 일치해야 접근 가능
- 교차 계정 접근은 차단

예시(개념):
- 허용: `profiles/{auth.uid()}/userProfile.jpg`
- 차단: `profiles/{other_user_id}/userProfile.jpg`

## 5. 운영 검증 SQL (핵심 통계)

### 5.1 오너별 세션/포인트/누적면적
```sql
select owner_user_id, session_count, point_count, total_area_m2
from public.view_owner_walk_stats
order by total_area_m2 desc;
```

### 5.2 산책 세션 대비 포인트 누락 확인
```sql
select
  ws.id as walk_session_id,
  ws.owner_user_id,
  count(wp.id) as point_count
from public.walk_sessions ws
left join public.walk_points wp on wp.walk_session_id = ws.id
group by ws.id, ws.owner_user_id
having count(wp.id) = 0;
```

### 5.3 좌표 시퀀스 중복 확인
```sql
select walk_session_id, seq_no, count(*)
from public.walk_points
group by walk_session_id, seq_no
having count(*) > 1;
```

### 5.4 N:M 브릿지 누락 확인
```sql
select count(*) as missing_bridge_count
from public.walk_sessions ws
left join public.walk_session_pets wsp on wsp.walk_session_id = ws.id
where ws.pet_id is not null
  and wsp.walk_session_id is null;
```

### 5.5 User/Pet 확장 필드 정합성 확인 (#114)
```sql
select
  p.id as user_id,
  p.profile_message,
  pet.id as pet_id,
  pet.breed,
  pet.age_years,
  pet.gender
from public.profiles p
left join public.pets pet on pet.owner_user_id = p.id
where p.id = ':user_uuid'::uuid
order by pet.created_at asc;
```

기대값:
- `gender`는 `unknown|male|female` 중 하나
- `age_years`는 `null` 또는 `0..30`
- 로컬 UserDefaults 저장값과 조회 결과가 동일

### 5.6 비교군 카탈로그/시드 정합성 확인 (#121)
```sql
select
  c.code as catalog_code,
  c.name as catalog_name,
  count(r.id) as reference_count,
  sum(case when r.is_featured then 1 else 0 end) as featured_count,
  min(r.display_order) as min_display_order,
  max(r.display_order) as max_display_order
from public.area_reference_catalogs c
left join public.area_references r on r.catalog_id = c.id and r.is_active = true
where c.is_active = true
group by c.code, c.name
order by c.sort_order asc, c.code asc;
```

기대값:
- 활성 카탈로그별 `reference_count`가 0보다 큼
- `featured_count`가 최소 1개 이상(큐레이션 카탈로그 기준)
- `display_order`가 음수 없이 정렬 가능 범위로 유지

### 5.7 시즌 안티 농사 점수 검증 (#146)
```sql
select *
from public.rpc_score_walk_session_anti_farming(
  ':walk_session_uuid'::uuid,
  now()
);
```

기대값:
- 동일 타일 반복 입력이 많은 세션은 `repeat_suppressed_count`가 증가
- `score_blocked=true`일 때 `total_score=0`
- `explain.ui_reason`에 차단/감쇠 사유가 포함

감사 로그 확인:
```sql
select
  severity,
  blocked,
  repeat_suppressed_count,
  novelty_ratio,
  session_distance_m,
  created_at
from public.season_score_audit_logs
where walk_session_id = ':walk_session_uuid'::uuid
order by created_at desc
limit 20;
```

### 5.8 시즌 복귀 캐치업 버프 검증 (#145)
```sql
select
  catchup_bonus,
  catchup_buff_active,
  catchup_buff_granted_at,
  catchup_buff_expires_at,
  explain -> 'catchup_buff' as catchup_buff
from public.rpc_score_walk_session_anti_farming(
  ':walk_session_uuid'::uuid,
  now()
);
```

기대값:
- 조건 충족 시 `catchup_buff_active=true` 또는 `explain.catchup_buff.status='granted|active'`
- 버프는 신규 타일 점수 기반으로만 `catchup_bonus` 반영
- 차단 케이스는 `explain.catchup_buff.block_reason`에 사유가 남음

지급 원장 확인:
```sql
select
  status,
  blocked_reason,
  granted_at,
  expires_at,
  boost_rate,
  abuse_flag
from public.season_catchup_buff_grants
where owner_user_id = ':user_uuid'::uuid
order by created_at desc
limit 20;
```

### 5.9 체감 날씨 피드백 KPI 검증 (#151)
```sql
select
  day_bucket,
  submitted_count,
  rate_limited_count,
  changed_count,
  unchanged_count,
  changed_ratio,
  rate_limited_ratio
from public.view_weather_feedback_kpis_7d
order by day_bucket desc
limit 7;
```

기대값:
- 피드백 이벤트가 발생한 일자에 `submitted_count`/`rate_limited_count`가 반영
- 위험도 재평가 이벤트에서 `changed_ratio`가 0~1 범위로 계산
- 제한 발생 시 `rate_limited_ratio`가 증가

### 5.10 라이벌 공정 리그 매칭 검증 (#149)
주간 스냅샷 재산정:
```sql
select *
from public.rpc_refresh_rival_leagues(
  date_trunc('week', now())::date,
  now()
);
```

본인 리그 조회:
```sql
select *
from public.rpc_get_my_rival_league(auth.uid(), now());
```

분포 확인:
```sql
select
  snapshot_week_start,
  league,
  effective_league,
  user_count,
  fallback_count
from public.view_rival_league_distribution_current
order by effective_league, league;
```

기대값:
- 리그가 `onboarding/light/mid/hardcore`로 배정됨
- 표본 부족 리그에서 `fallback_applied` + `effective_league` 병합 반영
- 변경 사용자는 `rival_league_history`에 이력이 기록됨

### 5.11 날씨 치환/스트릭 보호 엔진 검증 (#134)
서버 판정 호출:
```sql
select *
from public.rpc_apply_weather_replacement(
  ':user_uuid'::uuid,
  ':walk_session_uuid'::uuid,
  'bad',
  'outdoor.default',
  'indoor.routine',
  now()
);
```

치환 이력 확인:
```sql
select
  owner_user_id,
  day_key,
  risk_level,
  source_quest_id,
  replacement_quest_id,
  shield_applied,
  created_at
from public.weather_replacement_histories
where owner_user_id = ':user_uuid'::uuid
order by created_at desc
limit 20;
```

Shield 원장 확인:
```sql
select
  owner_user_id,
  week_start,
  day_key,
  reason,
  consumed_at
from public.weather_shield_ledgers
where owner_user_id = ':user_uuid'::uuid
order by consumed_at desc
limit 20;
```

14일 감사 뷰:
```sql
select
  day_key,
  risk_level,
  replacement_count,
  shield_applied_count
from public.view_weather_replacement_audit_14d
order by day_key desc, risk_level asc;
```

기대값:
- `bad|severe` 리스크에서 치환 이력이 생성됨
- 동일 사용자 동일 일자 2회 호출 시 `daily_limit_reached` 차단
- 같은 주차에서 `weekly_shield_limit=1`을 초과하지 않음
- `weather_replacement_histories`에 원/치환 퀘스트 ID와 사유가 누락 없이 저장됨

### 5.12 시즌 Stage1 정책 검증 (#124)
시즌 점수/감쇠/티어 파라미터 확인:
```sql
select
  policy_key,
  base_tile_score,
  new_route_bonus_weight,
  repeat_cooldown_minutes,
  suspicious_repeat_threshold
from public.season_scoring_policies
where policy_key = 'season_tile_anti_farming_v1';
```

복귀/보정 파라미터 확인:
```sql
select
  policy_key,
  inactivity_threshold_hours,
  buff_active_hours,
  score_boost_rate,
  weekly_issue_limit,
  season_end_block_hours
from public.season_catchup_buff_policies
where policy_key = 'season_comeback_catchup_v1';
```

기대값:
- 운영 파라미터가 Stage1 정책 문서(`docs/season-weekly-policy-stage1-v1.md`)의 기본값 범위를 벗어나지 않음
- 시즌 종료 지연창(`2h`) 운영 규칙이 앱/운영 문서와 일치
- 티어 컷(80/180/320/520) 및 동점 우선순위가 문서/클라이언트 표시 로직과 동일

### 5.13 시즌 Stage2 집계/정산 파이프라인 검증 (#125)
타일 이벤트 적재(멱등) 호출:
```sql
select *
from public.rpc_ingest_season_tile_events(
  ':walk_session_uuid'::uuid,
  now()
);
```

동일 요청 재호출 후 중복 여부 확인:
```sql
select
  season_id,
  owner_user_id,
  tile_id,
  event_day,
  count(*) as row_count
from public.tile_events
where source_walk_session_id = ':walk_session_uuid'::uuid
group by season_id, owner_user_id, tile_id, event_day
having count(*) > 1;
```

감쇠 배치 재실행 검증(service_role):
```sql
select *
from public.rpc_apply_season_daily_decay(
  ':season_id'::uuid,
  now()
);
```

정산 실행 검증(service_role):
```sql
select *
from public.rpc_finalize_season(
  ':season_id'::uuid,
  now()
);
```

리더보드 조회 검증:
```sql
select *
from public.rpc_get_season_leaderboard(
  ':season_id'::uuid,
  20
);
```

배치 상태 뷰 검증:
```sql
select
  season_key,
  status,
  participant_count,
  leaderboard_total_score,
  rewarded_user_count,
  last_decay_run_at,
  last_settlement_run_at
from public.view_season_batch_status_14d
order by season_key desc;
```

기대값:
- `tile_events`에 `(season_id, owner_user_id, tile_id, event_day)` 중복이 0건
- 감쇠 배치를 동일 시점으로 재실행해도 `season_user_scores.total_score`가 일관
- 정산 재실행 시 `season_rewards` 중복 발급이 발생하지 않음
- 리더보드 정렬이 정책 순서(`score -> active tile -> capture -> contribution time`)와 일치

### 5.14 퀘스트 Stage2 진행/클레임 엔진 검증 (#128)
일일 퀘스트 발급(멱등) 검증:
```sql
select *
from public.rpc_issue_quest_instances(
  ':user_uuid'::uuid,
  'daily',
  null,
  null,
  now()
);
```

동일 이벤트 재처리 멱등 검증:
```sql
select *
from public.rpc_apply_quest_progress_event(
  ':user_uuid'::uuid,
  ':quest_instance_uuid'::uuid,
  'walk-session-1:points:42:walk_duration',
  'walk_sync_points',
  12,
  jsonb_build_object('walk_session_id', ':walk_session_uuid'),
  now()
);
```

동일 요청 재호출 후 진행도 중복 검증:
```sql
select
  quest_instance_id,
  event_id,
  count(*) as row_count
from public.quest_progress
where quest_instance_id = ':quest_instance_uuid'::uuid
  and event_id = 'walk-session-1:points:42:walk_duration'
group by quest_instance_id, event_id;
```

클레임 경쟁 조건 검증(동일 instance에 동시 호출):
```sql
select *
from public.rpc_claim_quest_reward(
  ':user_uuid'::uuid,
  ':quest_instance_uuid'::uuid,
  'claim-request-1',
  now()
);
```

중복 클레임 원장 확인:
```sql
select
  quest_instance_id,
  count(*) as claim_row_count
from public.quest_claims
where quest_instance_id = ':quest_instance_uuid'::uuid
group by quest_instance_id;
```

상태 전이 검증(expire/reroll/replace):
```sql
select * from public.rpc_transition_quest_status(':user_uuid'::uuid, ':quest_instance_uuid'::uuid, 'expire', null, now());
select * from public.rpc_transition_quest_status(':user_uuid'::uuid, ':quest_instance_uuid'::uuid, 'reroll', null, now());
select * from public.rpc_transition_quest_status(':user_uuid'::uuid, ':quest_instance_uuid'::uuid, 'replace', 'daily.walk_duration.normal', now());
```

감사 로그 확인:
```sql
select
  action,
  detail,
  created_at
from public.quest_claim_audit_logs
where owner_user_id = ':user_uuid'::uuid
order by created_at desc
limit 30;
```

기대값:
- `quest_progress`에 `(quest_instance_id, event_id)` 중복이 0건
- `quest_claims`에 `quest_instance_id`당 1행만 존재(중복 수령 0건)
- `quest_claim_audit_logs`에 `claim_confirmed/duplicate_claim_blocked`가 요청 결과와 일치
- `reroll_transition`은 사용자당 UTC 일자 기준 1회만 허용
- `expire/reroll/replace` 상태 전이가 RPC 응답 `previous_status/current_status`와 동일

## 6. 운영 체크리스트
- [ ] `migration list --local` / `migration list --linked` 결과 저장
- [ ] User A/B 교차 접근 차단 SQL 결과 저장
- [ ] Storage 버킷 정책/경로 규칙 검증
- [ ] 핵심 통계 SQL 결과를 릴리스 문서에 첨부
- [ ] User/Pet 확장 필드 정합성 SQL 결과 첨부
- [ ] 비교군 카탈로그/시드 정합성 SQL 결과 첨부
- [ ] 시즌 안티 농사 RPC/감사 로그 검증 결과 첨부
- [ ] 시즌 Stage1 정책 파라미터 검증 결과 첨부
- [ ] 시즌 Stage2 집계/감쇠/정산/보상 파이프라인 검증 결과 첨부
- [ ] 퀘스트 Stage2 발급/진행/클레임/상태전이 검증 결과 첨부
- [ ] 체감 날씨 피드백 KPI 뷰 검증 결과 첨부
- [ ] 날씨 치환/Shield RPC 및 이력 원장 검증 결과 첨부
- [ ] 라이벌 리그 스냅샷/분포/히스토리 검증 결과 첨부
