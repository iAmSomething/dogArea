# Area Reference DB UI Transition v1

## 1. 목표
- `AreaMeters.swift` 정적 비교군 의존을 완화하고, Supabase `area_reference_catalogs/area_references`를 UI 소스로 우선 사용한다.
- 원격 조회 실패 시 기존 로컬 비교군으로 자동 fallback 한다.

## 2. 적용 범위
- Home 목표 카드(`nextGoalArea`)를 DB 비교군 기준으로 계산
- AreaDetail 화면에 카탈로그 기반 비교군 리스트 노출
- featured/display_order/catalog 필터를 일관 적용

## 3. 데이터 우선순위
1. 원격 DB(`area_reference_catalogs`, `area_references`)
2. 로컬 fallback(`AreaMeterCollection` 하드코딩)

## 4. 정렬/필터 규칙
- catalog: `is_active=true`, `sort_order ASC`
- reference: `is_active=true`, 활성 catalog에 속한 데이터만 노출
- 섹션 내부 정렬:
  - `is_featured DESC`
  - `display_order ASC`
  - `area_m2 DESC`
- Home 목표 계산:
  - featured 비교군 우선
  - featured가 비어 있으면 전체 비교군 사용

## 5. UX 반영
- Home 목표 카드에 데이터 소스/featured 개수 안내
  - 예: `비교군 소스: DB 비교군 · featured 12개 우선`
- AreaDetail에 `비교군 카탈로그` 섹션 추가
  - 각 카탈로그별 상위 5개 reference와 면적 표시

## 6. fallback 정책
- `SUPABASE_URL`/`SUPABASE_ANON_KEY` 미설정 또는 네트워크 실패 시 fallback
- 라벨을 `로컬 비교군 (Fallback)`으로 표시해 운영 상태를 인지 가능하게 함

## 7. 완료 기준
- Home/AreaDetail 비교군 UI가 DB 변경을 반영
- 정렬/featured/catalog 규칙이 코드 레벨로 고정
- 원격 실패 시 앱 동작 유지(로컬 fallback)
