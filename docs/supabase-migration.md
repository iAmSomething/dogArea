# Supabase Migration & Ops Verification v1

## 1. 목적
`profiles/pets/walk_sessions/walk_points/area_milestones/walk_session_pets`와 Storage 정책을 운영 기준으로 검증하기 위한 실행 절차/SQL 세트를 고정한다.

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

### 5.8 체감 날씨 피드백 KPI 검증 (#151)
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

## 6. 운영 체크리스트
- [ ] `migration list --local` / `migration list --linked` 결과 저장
- [ ] User A/B 교차 접근 차단 SQL 결과 저장
- [ ] Storage 버킷 정책/경로 규칙 검증
- [ ] 핵심 통계 SQL 결과를 릴리스 문서에 첨부
- [ ] User/Pet 확장 필드 정합성 SQL 결과 첨부
- [ ] 비교군 카탈로그/시드 정합성 SQL 결과 첨부
- [ ] 시즌 안티 농사 RPC/감사 로그 검증 결과 첨부
- [ ] 체감 날씨 피드백 KPI 뷰 검증 결과 첨부
