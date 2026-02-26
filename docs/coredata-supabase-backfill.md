# CoreData -> Supabase Backfill 설계 메모

## 목적
기존 로컬 저장(CoreData) 산책 데이터를 Supabase 스키마로 안전하게 이관하기 위한 구현 기준.

## 원본 -> 대상 매핑

### Polygon (CoreData) -> walk_sessions
- `uuid` -> `id` (UUID 재사용)
- `createdAt` -> `started_at` (임시 기준)
- `walkingTime` -> `duration_sec`
- `walkingArea` -> `area_m2`
- `mapImage` -> `map_image_url` (업로드 후 URL)
- `owner_user_id` -> Supabase auth uid (매핑 필요)
- `pet_id` -> 선택 반려견 id (미지정 시 기본 반려견)

### LocationEntity -> walk_points
- `uuid`는 무시
- `Polygon.uuid` -> `walk_session_id`
- 배열 index -> `seq_no`
- `x` -> `lat`
- `y` -> `lng`
- `createdAt` -> `recorded_at`

### AreaEntity -> area_milestones
- `areaName` -> `area_name`
- `areaSize` -> `area_m2`
- `createdAt` -> `achieved_at`
- `owner_user_id`, `pet_id`는 사용자/선택 반려견 기반

## 백필 순서
1. 사용자/반려견 레코드 준비 (profiles, pets)
2. 산책 세션(walk_sessions) 업서트
3. 산책 포인트(walk_points) 배치 insert
4. 마일스톤(area_milestones) insert
5. 검증 SQL 실행

## 검증 SQL
```sql
-- 세션 개수 비교
select count(*) from walk_sessions where owner_user_id = :uid;

-- 포인트 개수 비교
select count(*) from walk_points wp
join walk_sessions ws on ws.id = wp.walk_session_id
where ws.owner_user_id = :uid;

-- 누적 면적/시간 비교
select
  coalesce(sum(area_m2), 0) as total_area,
  coalesce(sum(duration_sec), 0) as total_duration
from walk_sessions
where owner_user_id = :uid;
```

## 구현 체크리스트
- [ ] CoreData fetch -> DTO 변환기 작성
- [ ] idempotent 업서트 전략(on conflict) 적용
- [ ] 실패 건 retry 큐 저장
- [ ] 검증 리포트(총 건수/면적/시간) 출력

## 주의
- Supabase RLS를 우회하기 위해 앱에서 service role 사용 금지.
- 백필은 인증된 사용자 토큰 기준 + 필요 시 서버 프록시로 수행.
