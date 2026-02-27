# Cycle 139 Report — Area Reference UI DB Transition (2026-02-27)

## 1. 대상
- Issue: `#139 [P1][Task] 비교군 UI DB 전환 (AreaMeters.swift 정적 의존 축소)`
- Branch: `codex/cycle-139-area-ui-db`

## 2. 구현 요약
- `AreaReferenceRepository` 추가: Supabase `area_reference_catalogs/area_references` 조회
- DB 조회 실패/미설정 시 로컬 `AreaMeterCollection` fallback 유지
- Home 목표 카드에 DB 소스 라벨/featured 우선 정보 노출
- Home 목표 계산에서 featured 비교군 우선 적용
- AreaDetail에 `비교군 카탈로그` 섹션 추가
  - catalog 기준 분리
  - `featured -> display_order -> area` 순 정렬
- 기존 정적 구조는 fallback 용도로만 유지되도록 리팩터링

## 3. 변경 파일
- `dogArea/Views/HomeView/AreaMeters.swift`
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/HomeView/HomeView.swift`
- `dogArea/Views/HomeView/AreaDetailView.swift`
- `docs/area-reference-db-ui-transition-v1.md`
- `docs/release-regression-checklist-v1.md`
- `docs/cycle-139-area-reference-db-ui-report-2026-02-27.md`
- `scripts/area_reference_db_ui_unit_check.swift`
- `scripts/release_regression_checklist_unit_check.swift`
- `scripts/ios_pr_check.sh`
- `README.md`

## 4. 유닛 체크
- `swift scripts/area_reference_db_ui_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 현재 DB 조회는 앱 환경변수(`SUPABASE_URL`, `SUPABASE_ANON_KEY`) 기반이라 미설정 런타임에서는 fallback으로 동작한다.
- 카탈로그별 표시 개수는 AreaDetail에서 상위 5개로 제한되어 있어, 전체 탐색 UX가 필요하면 별도 페이지네이션/검색 이슈로 분리 필요.
