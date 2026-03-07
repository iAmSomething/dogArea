# Backend Realtime / Moderation Retention Policy v1

Date: 2026-03-07  
Issue: #432

## 목적

live presence / hotspot / moderation 데이터는 모두 "실시간"처럼 보이지만, 실제 운영에서는 성격이 다릅니다.

이 문서는 아래를 분리해서 고정합니다.

- stale exclusion: 조회에서 숨기는 기준
- hard delete: 물리 row 삭제 기준
- audit retention: 운영/감사용 row 보관 기준
- cache retention: 재생성 가능한 파생 캐시 보관 기준

## Retention Class

### 1. `ephemeral_realtime`

현재 지도/근처 표시를 위한 짧은 수명의 raw row입니다.

원칙:

- stale exclusion이 먼저 적용됩니다.
- stale exclusion은 delete가 아닙니다.
- hard delete는 짧은 주기로 별도 수행합니다.

### 2. `derived_operational_state`

실시간 기능을 지원하는 상태/state window 데이터입니다.

원칙:

- 최근 동작/제재 판단에 필요할 때만 유지
- 장기 감사 목적 보관 금지

### 3. `operational_audit`

privacy/abuse 판정과 운영 장애 분석에 쓰는 감사성 로그입니다.

원칙:

- 원본 raw row는 중기 보관
- 장기 분석은 집계/요약으로 대체

### 4. `moderation_audit`

권리경로/제재/반복 남용 판단에 쓰는 장기 감사 로그입니다.

원칙:

- 운영성 audit보다 더 길게 보관
- 다만 무기한 보관은 하지 않음

### 5. `preference_or_identity`

사용자 설정/프로필 성격 데이터입니다.

원칙:

- TTL 대상이 아님
- 계정 삭제/개인정보 삭제 흐름에 맞춰 제거

## 핵심 구분: stale exclusion vs delete

### stale exclusion

조회에서만 숨깁니다.

예:

- `nearby_presence.last_seen_at >= now() - interval '10 minutes'`
- `walk_live_presence.expires_at > now()`

즉, stale exclusion만으로는 row가 디스크에서 사라지지 않습니다.

### hard delete

실제 테이블 row를 물리 삭제합니다.

예:

- `rpc_cleanup_walk_live_presence()`가 `expires_at <= now()` row를 삭제

운영자는 stale exclusion이 있는 것과 hard delete가 있는 것을 같은 것으로 보면 안 됩니다.

## Inventory

| Surface | Class | Current freshness gate | Target hard delete / raw retention | Current enforcement | Notes |
| --- | --- | --- | --- | --- | --- |
| `walk_live_presence` | `ephemeral_realtime` | `expires_at > now()` | `90초 TTL`, cron debt 허용은 분 단위 | 있음 | `pg_cron` `walk_live_presence_ttl_cleanup` |
| `nearby_presence` | `ephemeral_realtime` | `last_seen_at >= now() - 10m` | `24시간` inactivity 이후 hard delete | 없음 | 현재는 stale exclusion만 있고 physical cleanup 부재 |
| `widget_hotspot_summary_cache` | `derived_operational_state` | cache freshness `20초/300초` | `24시간` 이후 hard delete 권장 | 없음 | rebuild 가능한 per-user cache |
| `user_visibility_settings` | `preference_or_identity` | 없음 | 계정 삭제 또는 explicit privacy reset 시 삭제 | 부분적 | TTL 대상 아님 |
| `privacy_guard_audit_logs` | `operational_audit` | `view_privacy_guard_alerts_24h`는 조회 집계일 뿐 | raw `30일` | 없음 | privacy suppression / mask / k-anon 근거 |
| `live_presence_abuse_states` | `derived_operational_state` | sanction / recent state only | `max(sanction_until, updated_at) + 7일` | 없음 | live presence 제재 상태 |
| `live_presence_abuse_device_windows` | `derived_operational_state` | 최근 rate-limit window만 유효 | `updated_at + 24시간` | 없음 | rate-limit device window |
| `live_presence_abuse_events` | `operational_audit` | `view_live_presence_abuse_report_24h`는 조회 집계일 뿐 | raw `30일` | 없음 | speed/jump/rate/repeat/sanction 이벤트 |
| `rival_abuse_audit_logs` | `moderation_audit` | 별도 freshness 없음 | raw `90일` | 없음 | 시즌/리그 남용 판단 근거 |

## Surface별 정책

### 1. `walk_live_presence`

근거:

- `supabase/migrations/20260305103000_walk_live_presence_schema_rpc_ttl_rls.sql`
- `docs/backend-scheduler-ops-standard-v1.md`

정책:

- stale exclusion 기준: `expires_at > now()`
- write TTL clamp: `60초 ~ 90초`, 기본 `90초`
- hard delete: `rpc_cleanup_walk_live_presence()` + `pg_cron` 매분

운영 해석:

- 이것은 retention policy가 이미 코드로 강제되는 케이스입니다.
- stale exclusion과 delete가 둘 다 존재합니다.

### 2. `nearby_presence`

근거:

- `supabase/migrations/20260226095500_nearby_hotspots.sql`
- `docs/nearby-anonymous-hotspot-v1.md`

정책:

- stale exclusion 기준: `last_seen_at >= now() - interval '10 minutes'`
- target hard delete: `24시간` inactivity 이후
- opt-out 또는 계정 삭제 흐름에서는 즉시 삭제 우선

운영 해석:

- 현재 구현은 hot query에서 stale row를 숨기지만, inactivity cleanup scheduler는 없습니다.
- 따라서 현재 상태는 **freshness policy는 있음, retention enforcement는 미완료**입니다.

### 3. `widget_hotspot_summary_cache`

근거:

- `supabase/migrations/20260303203000_hotspot_widget_summary_rpc.sql`

정책:

- freshness gate:
  - `min_refresh_gap_seconds = 20`
  - `cache_ttl_seconds = 300`
- target hard delete: `cached_at + 24시간`

운영 해석:

- 캐시는 재생성 가능한 파생 데이터입니다.
- source retention보다 오래 보관할 이유가 없으므로 장기 보존 금지입니다.

### 4. `privacy_guard_audit_logs`

근거:

- `supabase/migrations/20260227192000_rival_privacy_hard_guard.sql`
- `docs/rival-privacy-hard-guard-v1.md`

정책:

- raw audit retention: `30일`
- 장기 운영 분석은 `24h/7d` 집계 뷰 또는 요약 materialization으로 대체
- payload에는 필요한 privacy 판정 근거만 남기고 좌표 원문 장기보관 금지

운영 해석:

- 이는 실시간 source가 아니라 privacy 운영 감사 로그입니다.
- 법률 자문 범위를 넘는 보존은 이 문서에서 다루지 않지만, 운영 기본값은 `30일`로 고정합니다.

### 5. `live_presence_abuse_states`

근거:

- `supabase/migrations/20260305165000_walk_live_presence_anti_abuse_engine.sql`

정책:

- retention target: `greatest(sanction_until, updated_at) + 7일`
- 목적: 최근 제재 상태와 디바이스/유저 window 재구성
- 장기 감사 목적 보관 금지

### 6. `live_presence_abuse_device_windows`

정책:

- retention target: `updated_at + 24시간`
- 목적: rate-limit / flood control 재진입 방지
- 장기 감사 목적 보관 금지

### 7. `live_presence_abuse_events`

근거:

- `view_live_presence_abuse_report_24h`
- `view_live_presence_abuse_top_users_24h`

정책:

- raw event retention: `30일`
- 운영 집계는 24h 뷰/주간 리포트로 대체

운영 해석:

- 이벤트 row는 근거 보관용이지만 moderation 장기 원장 수준은 아닙니다.
- 따라서 `30일`이 상한입니다.

### 8. `rival_abuse_audit_logs`

근거:

- `supabase/migrations/20260301153000_rival_stage2_leaderboard_backend.sql`

정책:

- raw audit retention: `90일`
- account delete / 내 데이터 삭제 경로에서는 즉시 삭제 허용

운영 해석:

- 시즌/주간 리그 부정행위 근거는 단일 주기보다 길게 봐야 합니다.
- 하지만 무기한 raw 보관은 금지하고 `90일` 기준으로 닫습니다.

## 삭제 우선순위

### 즉시 삭제 대상

- `walk_live_presence`: TTL 만료 row
- `nearby_presence`: opt-out / account delete / inactivity cleanup target row

### 짧은 주기 cleanup 대상

- `widget_hotspot_summary_cache`
- `live_presence_abuse_device_windows`

### 중기 audit cleanup 대상

- `privacy_guard_audit_logs`
- `live_presence_abuse_states`
- `live_presence_abuse_events`

### 장기 moderation cleanup 대상

- `rival_abuse_audit_logs`

## 현재 구현 상태

### 이미 enforcement가 있는 것

- `walk_live_presence` TTL + hard delete scheduler
- 일부 사용자 삭제 경로에서 `nearby_presence`, `rival_abuse_audit_logs` explicit delete
- `widget_hotspot_summary_cache`는 `auth.users` cascade에 의해 계정 삭제 시 제거

### 아직 문서만 있고 enforcement가 없는 것

- `nearby_presence` inactivity hard delete
- `widget_hotspot_summary_cache` age-based cleanup
- `privacy_guard_audit_logs` raw retention cleanup
- `live_presence_abuse_states` / `device_windows` / `events` retention cleanup
- `rival_abuse_audit_logs` age-based cleanup

## 후속 작업

필요한 후속:

- retention cleanup RPC / scheduler / manual runbook 추가
- privacy/moderation raw log cleanup SQL과 verification query 추가

분리 이슈:

- `#467` backend realtime/moderation retention cleanup rollout

## 운영 규칙

1. stale exclusion을 retention enforcement로 오해하지 않는다.
2. 캐시는 source보다 오래 보관하지 않는다.
3. raw audit는 중기/장기 보관이더라도 무기한 보관하지 않는다.
4. scheduler가 없는 retention rule은 문서상 target일 뿐이며, rollout 전까지는 "gap"으로 취급한다.

## Validation

- `swift scripts/backend_realtime_moderation_retention_policy_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## Related

- `docs/backend-scheduler-ops-standard-v1.md`
- `docs/nearby-anonymous-hotspot-v1.md`
- `docs/rival-privacy-hard-guard-v1.md`
- `docs/backend-edge-failure-dashboard-view-v1.md`
