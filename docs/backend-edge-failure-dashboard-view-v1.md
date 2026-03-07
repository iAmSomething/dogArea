# Backend Edge Failure Dashboard View v1

Date: 2026-03-07  
Issue: #430

## 목적

앱 KPI와 별개로, Supabase backend 장애를 운영자가 backend 관점에서 바로 읽을 수 있는 정규화된 집계 뷰 기준을 고정합니다.

이 문서는 두 가지를 함께 정의합니다.

- `public.view_backend_edge_failure_dashboard_24h`의 Phase 1 정규화 shape
- 현재 저장소에서 실제로 집계 가능한 failure source와 coverage 한계

## 읽어야 하는 기준 축

대시보드는 아래 축으로 읽을 수 있어야 합니다.

- `function_name`
- `error_code`
- `failure_category`
- `auth_mode`
- `fallback_used`
- `hour_bucket`
- `event_count`
- `affected_users`
- `avg_latency_ms`
- `p95_latency_ms`
- `data_source`

## Phase 1 데이터 소스

Phase 1은 이미 DB에 durable row가 남는 소스만 포함합니다.

| Data source | Function coverage | What it represents | Notes |
| --- | --- | --- | --- |
| `public.caricature_jobs` | `caricature` | provider/storage/db failure, fallback, latency | 현재 가장 표준에 가까운 source |
| `public.privacy_guard_audit_logs` | `nearby-presence` | privacy suppression / mask / k-anon gate | hotspot/privacy failure 해석용 |
| `public.live_presence_abuse_events` | `nearby-presence` | abuse sanction / rate / jump / repeat | live presence abuse failure 해석용 |

보조 KPI source:

- `public.view_rollout_kpis_24h`
  - backend failure source는 아니지만 rollout degradation과 함께 읽을 보조 지표입니다.

## 현재 Phase 1에 없는 함수

아래 함수는 아직 failure dashboard view에 full-fidelity로 들어오지 않습니다.

- `sync-walk`
- `sync-profile`
- `rival-league`
- `quest-engine`
- `feature-control`
- `upload-profile-image`

이유:

- request 단위 durable audit row가 아직 없습니다.
- `function_name / error_code / auth_mode / fallback_used / latency_ms`가 같은 row에서 함께 남지 않습니다.

관련 정리:

- `docs/backend-edge-observability-adoption-matrix-v1.md`
- `docs/backend-edge-observability-standard-v1.md`
- `docs/backend-edge-incident-runbook-v1.md`

## 정규화 view shape

`public.view_backend_edge_failure_dashboard_24h`는 아래 shape를 목표로 합니다.

| Column | Meaning |
| --- | --- |
| `hour_bucket` | 시간 버킷 |
| `function_name` | canonical Edge Function 이름 |
| `error_code` | machine-readable canonical 또는 compat code |
| `failure_category` | `auth`, `contract`, `validation`, `unavailable`, `privacy`, `upstream`, `abuse` |
| `auth_mode` | `anon`, `authenticated`, `service_role_proxy`, `mixed` 또는 `NULL` |
| `fallback_used` | fallback/auth downgrade/provider fallback이 사용되었는지 |
| `event_count` | 해당 버킷에서의 장애 건수 |
| `affected_users` | 영향받은 고유 사용자 수 |
| `avg_latency_ms` | 평균 지연 시간 |
| `p95_latency_ms` | 95 percentile 지연 시간 |
| `data_source` | 원본 소스 식별자 |

## Phase 1 SQL view

저장소 migration 초안은 다음 view를 정의합니다.

- `public.view_backend_edge_failure_dashboard_24h`

정규화 전략:

1. `caricature_jobs`는 error/fallback/latency를 거의 그대로 반영
2. `privacy_guard_audit_logs`는 privacy suppression event를 canonical privacy code로 재매핑
3. `live_presence_abuse_events`는 event type을 canonical abuse code로 재매핑
4. 현재 저장되지 않는 값은 `NULL` 허용

## 운영 해석 규칙

### 1. function별 장애 상위 원인

`function_name`, `error_code`, `event_count` 기준으로 읽습니다.

예시:

- `caricature` / `ALL_PROVIDERS_FAILED`
- `nearby-presence` / `PRIVACY_K_ANON_SUPPRESSED`
- `nearby-presence` / `ABUSE_RATE_DEVICE`

### 2. auth failure 해석

Phase 1에서는 `auth_mode`가 durable row에 남는 source가 제한적입니다.

- `caricature_jobs`: `source_type` 기반 준-정규화 가능
- `privacy_guard_audit_logs`: payload에 auth metadata가 들어간 경우만 읽음
- `live_presence_abuse_events`: detail에 auth metadata가 들어간 경우만 읽음

따라서 `auth_mode`는 현재 nullable dimension으로 해석합니다.

### 3. fallback ratio 해석

현재 `fallback_used`를 신뢰성 있게 읽을 수 있는 source는 사실상 `caricature_jobs`가 중심입니다.

운영상 fallback ratio는 아래 방식으로 봅니다.

- per function fallback rate:
  - `sum(case when fallback_used then event_count else 0 end) / sum(event_count)`
- source coverage note:
  - fallback persisted source가 없는 함수는 ratio를 `N/A`로 취급

## 추천 대시보드 패널

### A. 24h function failure heatmap

축:

- x: `hour_bucket`
- y: `function_name`
- metric: `sum(event_count)`

### B. 24h error code leaderboard

축:

- group: `error_code`
- metric: `sum(event_count)`

### C. nearby-presence privacy vs abuse split

축:

- group: `failure_category`
- filter: `function_name = 'nearby-presence'`
- metric: `sum(event_count)`

### D. caricature fallback and upstream failures

축:

- group: `error_code`, `fallback_used`
- filter: `function_name = 'caricature'`
- metric: `sum(event_count)`

### E. rollout KPI companion panel

보조 source:

- `public.view_rollout_kpis_24h`

용도:

- backend failure 급증과 rollout KPI degradation을 나란히 확인

## 쿼리 예시

### 1. 함수별 장애 집계

```sql
select
  function_name,
  error_code,
  sum(event_count) as total_events,
  sum(affected_users) as total_affected_users
from public.view_backend_edge_failure_dashboard_24h
group by function_name, error_code
order by total_events desc, function_name asc;
```

### 2. fallback 사용 비율

```sql
select
  function_name,
  sum(case when fallback_used then event_count else 0 end)::double precision
    / nullif(sum(event_count), 0) as fallback_ratio
from public.view_backend_edge_failure_dashboard_24h
group by function_name
order by fallback_ratio desc nulls last;
```

### 3. category별 장애 추이

```sql
select
  hour_bucket,
  failure_category,
  sum(event_count) as event_count
from public.view_backend_edge_failure_dashboard_24h
group by hour_bucket, failure_category
order by hour_bucket desc, failure_category asc;
```

## Coverage 한계

이 view는 아직 "전체 Edge request audit"이 아닙니다.

해결되지 않은 부분:

- `sync-walk`, `sync-profile`, `rival-league`, `quest-engine`, `feature-control`, `upload-profile-image`는 request row가 없어 Phase 1 dashboard에서 제외
- `auth_mode`와 `fallback_used`는 source별 coverage 편차가 큼
- `p95_latency_ms`는 현재 `caricature_jobs` 중심으로만 의미가 있음

즉, 이 view는 **Phase 1 운영 해석용 정규화 view**이지 최종 canonical audit table이 아닙니다.

## 다음 단계

Phase 2 이후 작업:

1. remaining Edge Function에 request audit row 도입
2. 공통 `function_name / request_id / version / auth_mode / fallback_used / latency_ms / error_code` persisted metadata 확보
3. `view_backend_edge_failure_dashboard_24h`를 source union이 아니라 canonical audit source 기반으로 재작성

## Validation

- `swift scripts/backend_edge_failure_dashboard_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## Related

- `docs/backend-edge-observability-standard-v1.md`
- `docs/backend-edge-error-taxonomy-v1.md`
- `docs/backend-edge-incident-runbook-v1.md`
- `docs/backend-edge-observability-adoption-matrix-v1.md`
- `docs/feature-flag-rollout-monitoring-v1.md`
- `docs/supabase-integration-smoke-matrix-v1.md`
