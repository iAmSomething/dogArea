# Cycle #22 결과 보고서 (2026-02-26)

## 1. 이슈 확인
- 대상 이슈: `#22 [Task] Supabase 스키마/RLS/Storage 운영 고도화`
- 범위:
  - 핵심 테이블 제약/인덱스 보강
  - owner 기반 RLS 정책 고정
  - Storage(`profiles/caricatures/walk-maps`) 정책 고정
  - 운영 검증 SQL 문서화

## 2. 개발/문서 반영
- `supabase/migrations/20260226230000_supabase_schema_ops_hardening.sql` 추가
  - 핵심 테이블 생성/보강:
    - `profiles`, `pets`, `walk_sessions`, `walk_points`, `area_milestones`, `walk_session_pets`, `area_references`
  - 제약/인덱스 보강:
    - `walk_points(walk_session_id, seq_no)` unique
    - owner/시계열 조회 인덱스 추가
  - RLS 정책 보강:
    - owner 기반 접근(`auth.uid()`) 정책
    - `walk_points`, `walk_session_pets`는 `walk_sessions` 소유자 조인 검증
  - Storage 버킷/정책 보강:
    - `profiles`, `caricatures`, `walk-maps` 버킷 비공개 보장
    - 객체 경로 첫 세그먼트=`auth.uid()` 기반 정책 추가
  - 운영 통계 view:
    - `public.view_owner_walk_stats`
- `docs/supabase-migration.md` 추가
  - local/linked migration 동기화 절차
  - A/B 교차 접근 차단 SQL
  - Storage 정책 검증 기준
  - 핵심 통계 검증 SQL 세트
- `scripts/supabase_ops_hardening_unit_check.swift` 추가
  - migration/문서 계약 검증
- `scripts/ios_pr_check.sh` 갱신
  - Supabase ops 유닛 체크를 공통 PR 체크에 포함
- `README.md`, `docs/supabase-schema-v1.md`에 운영 문서 링크 반영

## 3. 유닛 테스트
- `swift scripts/supabase_ops_hardening_unit_check.swift` -> `PASS`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> `PASS`

## 4. Supabase 상태 검증 실행 결과
- `npx --yes supabase migration list --local` -> `BLOCKED`
  - 로컬 Postgres 미기동(`127.0.0.1:54322 connect refused`)
- `npx --yes supabase migration list --linked` -> `BLOCKED`
  - 프로젝트 ref 미링크(`supabase link` 필요)

## 5. 비고
- 이번 사이클은 운영 스키마/정책/검증 SQL 기준을 코드로 고정하는 데 초점을 맞췄다.
- local/linked 상태 동기화 확인은 Supabase 실행 환경(로컬 DB 기동 + linked ref) 준비 후 즉시 재실행 가능하다.
