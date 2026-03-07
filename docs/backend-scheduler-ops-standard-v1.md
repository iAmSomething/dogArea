# Backend Scheduler Ops Standard v1

Date: 2026-03-07  
Issue: #428

## 목적

season / rival / live presence 중심의 backend 운영 작업을 단일 기준으로 고정합니다.

이 문서는 다음 질문에 바로 답할 수 있어야 합니다.

- 어떤 작업이 언제 돌아야 하는가
- 실패하면 몇 번까지 자동 재시도하는가
- 수동 재실행은 어떤 SQL/RPC로 하는가
- 재실행이 안전한가, 아니면 범위를 좁혀야 하는가

## 운영 원칙

### 1. 기준 타임존

- 기본 타임존은 `UTC`
- 주간 경계는 `date_trunc('week', now() at time zone 'utc')`
- 일간 점검/배치 기준도 `UTC` 하루 경계로 계산

### 2. 작업 분류

- `writer`: 실제 데이터를 갱신하는 배치/RPC
- `verification`: 상태를 읽고 drift/stale 여부를 판단하는 운영 점검

### 3. 재시도 규칙

- `writer`는 실패 즉시 무한 반복하지 않습니다.
- 동일 원인 재시도는 정해진 횟수 안에서만 수행하고, 이후에는 수동 개입으로 전환합니다.
- 수동 재실행 시에는 가능하면 `target_*` 파라미터로 범위를 좁힙니다.

## 스케줄러 인벤토리

| job_key | class | source of truth | cadence (UTC) | retry | 재실행 성격 |
| --- | --- | --- | --- | --- | --- |
| `season.daily_decay` | writer | `rpc_apply_season_daily_decay` | 매일 `00:10` | `+15m`, `+45m`, `+105m` | 안전 재실행 |
| `season.finalize` | writer | `rpc_finalize_season` | 매주 월요일 `02:15` 이후 | `+30m`, `+90m` | 조건부 재실행 |
| `rival.weekly_refresh` | writer | `rpc_refresh_rival_leagues` | 매주 월요일 `00:20` | `+30m`, `+120m` | 안전 재실행 |
| `live_presence.ttl_cleanup` | writer | `rpc_cleanup_walk_live_presence` + `pg_cron` | 매분 | 다음 분 재실행 | 안전 재실행 |
| `weather.feedback_kpi_review` | verification | `view_weather_feedback_kpis_7d` | 매일 `01:00` | `+30m` 1회 | 읽기 전용 |
| `quest.expiry_review` | verification | `quest_instances.expires_at` | 매일 `01:10` | `+30m` 1회 | 읽기 전용 |

## 작업별 운영 기준

### 1. `season.daily_decay`

근거:

- migration: `supabase/migrations/20260301090000_season_stage2_batch_pipeline.sql`
- RPC: `public.rpc_apply_season_daily_decay(target_season_id uuid default null, now_ts timestamptz default now())`

실행 기준:

- 매일 `00:10 UTC`
- 주간 종료 이전 시즌은 `active`, 종료 후 정산 대기 기간에는 `settling`으로 유지

재시도:

- 자동 재시도: `00:25`, `00:55`, `01:55 UTC`
- 세 번 모두 실패하면 `P1 backend-data`로 격상

재실행 성격:

- `season_tile_scores` / `season_user_scores`를 현재 시점 기준으로 재계산하므로 안전 재실행
- 수동 재실행 시 전체 시즌 대신 대상 시즌을 좁혀 실행 권장

수동 재실행:

```sql
select *
from public.rpc_apply_season_daily_decay(
  ':season_id'::uuid,
  now()
);
```

실패 감지:

- `season_runs.last_decay_run_at`가 최근 하루 경계 이후로 갱신되지 않음
- `season_user_scores.score_updated_at`가 당일 갱신되지 않음

확인 SQL:

```sql
select
  id,
  season_key,
  status,
  last_decay_run_at,
  updated_at
from public.season_runs
order by week_start desc
limit 4;
```

### 2. `season.finalize`

근거:

- migration: `supabase/migrations/20260301090000_season_stage2_batch_pipeline.sql`
- RPC: `public.rpc_finalize_season(target_season_id uuid, now_ts timestamptz default now())`
- 기본 정산 지연: `settlement_delay_hours = 2`

실행 기준:

- 매주 월요일 `02:15 UTC`부터 대상 시즌 정산 가능
- `week_end + settlement_delay_hours` 이전에는 실행 금지

재시도:

- 자동 재시도: `02:45`, `03:45 UTC`
- 세 번 실패하면 rewards/season 상태를 수동 확인 후 개입

재실행 성격:

- `season_rewards`는 `on conflict do nothing`이므로 중복 reward 발급은 방지됨
- 단, 항상 같은 `target_season_id`를 명시해서 재실행

수동 재실행:

```sql
select *
from public.rpc_finalize_season(
  ':season_id'::uuid,
  now()
);
```

실패 감지:

- `season_runs.status = 'settling'`인데 `finalized_at is null`
- 정산 가능 시각을 지났는데 `last_settlement_run_at` 미갱신

확인 SQL:

```sql
select
  id,
  season_key,
  status,
  week_end,
  settlement_delay_hours,
  finalized_at,
  last_settlement_run_at
from public.season_runs
order by week_start desc
limit 4;
```

### 3. `rival.weekly_refresh`

근거:

- migration: `supabase/migrations/20260227212000_rival_fair_league_matching.sql`
- RPC: `public.rpc_refresh_rival_leagues(target_snapshot_week_start date default date_trunc('week', now())::date, now_ts timestamptz default now())`
- 정책 기본값: `weekly_refresh_interval_days = 7`, `lookback_days = 14`

실행 기준:

- 매주 월요일 `00:20 UTC`
- 주간 경계 직후 walk ingestion이 반영될 시간을 약간 둔 뒤 실행

재시도:

- 자동 재시도: `00:50`, `02:20 UTC`
- 실패 시 이번 주 `snapshot_week_start`만 대상으로 수동 재실행

재실행 성격:

- `rival_league_assignments`는 upsert 기반이라 같은 주차 재실행이 안전
- `rival_league_history`는 이전 assignment와 차이가 있을 때만 insert되므로 동일 결과 재실행은 중복 이력 증가를 일으키지 않음

수동 재실행:

```sql
select *
from public.rpc_refresh_rival_leagues(
  date_trunc('week', now())::date,
  now()
);
```

실패 감지:

- `rival_league_assignments.snapshot_week_start`가 현재 UTC week start보다 과거
- 현재 주 assignment는 있는데 `fallback_applied` 급증 또는 분포 왜곡

확인 SQL:

```sql
select
  snapshot_week_start,
  count(*) as total_users,
  count(*) filter (where fallback_applied) as fallback_users
from public.rival_league_assignments
group by snapshot_week_start
order by snapshot_week_start desc
limit 4;
```

### 4. `live_presence.ttl_cleanup`

근거:

- migration: `supabase/migrations/20260305103000_walk_live_presence_schema_rpc_ttl_rls.sql`
- RPC: `public.rpc_cleanup_walk_live_presence(in_now_ts timestamptz default now())`
- 내장 scheduler: `pg_cron` job `walk_live_presence_ttl_cleanup`

실행 기준:

- `pg_cron` 가능 환경에서는 매분 실행
- `cron` extension이 없는 환경은 scheduler가 skip될 수 있으므로 배포 후 상태 확인 필수

재시도:

- 별도 retry queue 없음
- 한 번 실패해도 다음 분 스케줄이 자연 재시도 역할
- 5분 연속 실패 시 수동 개입

재실행 성격:

- `expires_at <= now()` row delete이므로 안전 재실행

수동 재실행:

```sql
select public.rpc_cleanup_walk_live_presence(now());
```

실패 감지:

- `walk_live_presence`에 expired row가 누적
- `cron.job`에 `walk_live_presence_ttl_cleanup`가 없거나 비활성

확인 SQL:

```sql
select count(*) as expired_row_count
from public.walk_live_presence
where expires_at <= now();
```

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'walk_live_presence_ttl_cleanup';
```

### 5. `weather.feedback_kpi_review`

근거:

- doc: `docs/weather-feedback-loop-v1.md`
- view: `public.view_weather_feedback_kpis_7d`

실행 기준:

- 매일 `01:00 UTC`
- writer job이 아니라 KPI drift/stale 점검

재시도:

- `01:30 UTC` 1회 재시도

재실행 성격:

- 읽기 전용 확인이므로 안전

확인 SQL:

```sql
select
  day_bucket,
  submitted_count,
  rate_limited_count,
  changed_ratio
from public.view_weather_feedback_kpis_7d
order by day_bucket desc
limit 7;
```

운영 판정:

- 최근 24h 데이터가 비어 있거나 rate limit 비율이 비정상 급증하면 weather policy/feedback route를 점검

### 6. `quest.expiry_review`

근거:

- migration: `supabase/migrations/20260303120000_quest_stage2_progress_claim_engine.sql`
- 핵심 시각 필드: `quest_instances.expires_at`

실행 기준:

- 매일 `01:10 UTC`
- 별도 만료 정리 scheduler가 아니라, 만료 debt/상태 이상 유무를 운영자가 확인하는 verification 작업

재시도:

- `01:40 UTC` 1회 재시도

재실행 성격:

- 읽기 전용 확인이므로 안전

확인 SQL:

```sql
select
  status,
  count(*) as row_count
from public.quest_instances
where expires_at < now()
group by status
order by status asc;
```

운영 판정:

- `expires_at < now()`인데 장시간 `active`로 남아 있는 row가 증가하면 quest transition/claim path를 점검

## 실패 시 공통 수동 개입 순서

1. 현재 UTC 시각 기준으로 대상 작업이 진짜 실행 대상 시간대인지 확인
2. drift 게이트 실행

```bash
bash scripts/backend_migration_drift_check.sh
```

3. backend smoke 실행

```bash
DOGAREA_RUN_SUPABASE_SMOKE=1 \
DOGAREA_TEST_EMAIL="$DOGAREA_TEST_EMAIL" \
DOGAREA_TEST_PASSWORD="$DOGAREA_TEST_PASSWORD" \
bash scripts/backend_pr_check.sh
```

4. 범위를 좁힌 수동 SQL 재실행
5. 재실행 후 확인 SQL로 stale/debt 해소 여부 검증
6. 동일 원인 2회 이상 반복이면 scheduler 설정 문제가 아니라 migration drift / policy regression으로 간주

## 관련 문서

- `docs/supabase-migration.md`
- `docs/realtime-ops-rollout-killswitch-v1.md`
- `docs/backend-edge-incident-runbook-v1.md`
- `docs/backend-migration-drift-rpc-ci-check-v1.md`
