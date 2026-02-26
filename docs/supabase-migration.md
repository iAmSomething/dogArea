# Supabase Migration Runbook (DogArea)

## 목적
- CoreData/Firebase 기반 데이터를 Supabase로 점진 이관하기 위한 실행 절차.
- 1차 릴리스 기준: `산책 1건 = 반려견 1마리 귀속` 모델.

## 선행 조건
- Supabase CLI 사용 가능 (`npx supabase`)
- 프로젝트 링크 완료 (`ttjiknenynbhbpoqoesq`)
- 환경 변수 설정

```bash
export SUPABASE_DB_PASSWORD='<REMOTE_DB_PASSWORD>'
```

## 마이그레이션 파일
- `supabase/migrations/20260226152000_create_storage_buckets.sql`
- `supabase/migrations/20260226153000_create_dogarea_schema.sql`
- `supabase/migrations/20260226154000_storage_policies.sql`

## 적용 순서
1. dry run
```bash
npx --yes supabase db push --linked --dry-run --yes
```

2. 원격 적용
```bash
npx --yes supabase db push --linked --yes
```

3. 적용 이력 확인
```bash
npx --yes supabase migration list --linked
```

## 생성 리소스
- 테이블: `profiles`, `pets`, `walk_sessions`, `walk_points`, `area_milestones`, `walk_session_pets`
- 버킷: `profiles`, `caricatures`, `walk-maps`
- RLS/정책: 사용자 소유 데이터만 접근 가능

## 보안 주의
- `SUPABASE_SERVICE_ROLE_KEY`는 앱(xcconfig/Info.plist)에 넣지 않는다.
- Service Role 키는 Edge Function/서버 환경 변수에만 저장한다.
- 앱에는 `SUPABASE_URL`, `SUPABASE_ANON_KEY`만 사용한다.

## 롤백(초기 단계)
- 스키마 변경이 큰 경우 수동 롤백 SQL을 별도 작성하고, 운영 데이터 보존을 우선한다.
- bucket/object 삭제는 데이터 손실 위험이 있으므로 즉시 롤백보다 차단 정책 적용을 우선한다.
