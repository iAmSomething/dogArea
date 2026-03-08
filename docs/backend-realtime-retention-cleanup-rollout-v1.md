# Backend Realtime Retention Cleanup Rollout v1

Date: 2026-03-09  
Issue: #470

## 목적

#432에서 고정한 retention target을 실제 cleanup RPC / scheduler / verification query로 rollout합니다.

이 문서는 아래를 canonical artifact로 고정합니다.

- cleanup RPC: `public.rpc_cleanup_realtime_retention(in_now_ts timestamptz default now())`
- delete debt view: `public.view_realtime_retention_delete_debt`
- scheduler job: `realtime_retention_cleanup_hourly`

## Rollout Artifact

- migration: `supabase/migrations/20260309043000_realtime_retention_cleanup_rollout.sql`
- RPC: `public.rpc_cleanup_realtime_retention(...)`
- view: `public.view_realtime_retention_delete_debt`
- scheduler: `pg_cron` job `realtime_retention_cleanup_hourly`
- cadence: 매시 `17분 UTC`

## Cleanup Surface Matrix

| surface | class | delete rule | verification |
| --- | --- | --- | --- |
| `nearby_presence` | `ephemeral_realtime` | `last_seen_at <= now() - 24h` | overdue row / oldest `last_seen_at` |
| `widget_hotspot_summary_cache` | `derived_operational_state` | `cached_at <= now() - 24h` | overdue row / oldest `cached_at` |
| `privacy_guard_audit_logs` | `operational_audit` | `created_at <= now() - 30d` | overdue row / oldest `created_at` |
| `live_presence_abuse_states` | `derived_operational_state` | `greatest(coalesce(sanction_until, '-infinity'), updated_at) <= now() - 7d` | overdue row / oldest sanction-or-update anchor |
| `live_presence_abuse_device_windows` | `derived_operational_state` | `updated_at <= now() - 24h` | overdue row / oldest `updated_at` |
| `live_presence_abuse_events` | `operational_audit` | `created_at <= now() - 30d` | overdue row / oldest `created_at` |
| `rival_abuse_audit_logs` | `moderation_audit` | `created_at <= now() - 90d` | overdue row / oldest `created_at` |

## Verification Query

### 1. 현재 delete debt 확인

```sql
select *
from public.view_realtime_retention_delete_debt
order by overdue_rows desc, surface asc;
```

### 2. 실제 cleanup 수동 실행

```sql
select public.rpc_cleanup_realtime_retention(now());
```

### 3. cleanup 이후 debt 잔여 확인

```sql
select *
from public.view_realtime_retention_delete_debt
where overdue_rows > 0
order by overdue_rows desc, surface asc;
```

### 4. scheduler 존재 확인

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'realtime_retention_cleanup_hourly';
```

## 운영 해석

- stale exclusion은 조회 정책이고, 이 rollout은 physical cleanup enforcement입니다.
- `nearby_presence`는 `10분` stale exclusion과 별개로 `24시간` inactivity hard delete를 가집니다.
- `pg_cron`이 없는 환경에서는 scheduler가 skip될 수 있으므로, 배포 직후 view / RPC / `cron.job` 확인이 필수입니다.

## 완료 기준

- `public.rpc_cleanup_realtime_retention()`가 모든 target surface를 실제 삭제한다.
- `public.view_realtime_retention_delete_debt`로 overdue row를 surface별로 바로 볼 수 있다.
- `realtime_retention_cleanup_hourly` job이 배포 환경에 등록되어 있다.
- 수동 rerun과 post-deploy verification query가 문서화되어 있다.
