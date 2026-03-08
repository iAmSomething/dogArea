# Issue #506 Closure Evidence v1

## 대상
- issue: `#506`
- title: `indoor mission pet context 집계 snapshot/cache 도입`

## 구현 근거
- 구현 PR: `#534`
- 핵심 문서:
  - `docs/home-mission-pet-context-snapshot-v1.md`
- 핵심 구현 파일:
  - `dogArea/Source/Domain/Home/Services/HomeIndoorMissionPetContextSnapshotService.swift`
  - `dogArea/Views/HomeView/HomeViewModel.swift`
  - `dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift`
  - `dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift`

## DoD 판정
### 1. 같은 입력으로 반복 refresh가 들어와도 집계 본연의 비용이 중복되지 않음
- `HomeIndoorMissionPetContextSnapshotService`가 polygon fingerprint, 선택 반려견 식별자, 기준 시각을 기준으로 snapshot 재사용 여부를 판단한다.
- `refreshIndoorMissions(now:)`는 cache hit 시 최근 14일/28일 집계를 다시 `filter/reduce`하지 않고 기존 snapshot을 그대로 재사용한다.
- 판정: `PASS`

### 2. polygon 입력이 실제로 바뀔 때만 snapshot이 무효화됨
- `applySelectedPetStatistics(...)`가 집계 후 현재 홈 polygon 목록 기준 fingerprint를 갱신한다.
- fingerprint가 달라진 경우에만 `indoorMissionPetContextAggregationSnapshot`을 `nil`로 비워 재집계를 유도한다.
- 판정: `PASS`

### 3. 시간 경계와 선택 반려견 변경이 재사용 조건에 정확히 반영됨
- snapshot은 `selectedPetId`, `computedAt`, `validThrough`를 함께 저장한다.
- 같은 polygon 목록이라도 선택 반려견이 바뀌거나 시간 경계를 넘으면 재사용되지 않는다.
- 판정: `PASS`

### 4. 반려견 표시 정보는 cache와 분리되어 기존 UI 의미를 유지함
- snapshot은 집계값만 저장하고 `petName`, `ageYears`는 최종 `IndoorMissionPetContext` 조립 시점에 현재 선택 반려견에서 다시 읽는다.
- 따라서 성능 최적화가 홈 미션 카드 문구/난이도 의미를 바꾸지 않는다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/home_mission_pet_context_snapshot_unit_check.swift`
  - `swift scripts/home_refresh_entrypoint_unit_check.swift`
  - `swift scripts/issue_506_closure_evidence_unit_check.swift`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#506`의 요구사항은 구현, 문서, 정적 체크 근거까지 확보됐다.
- 이 문서를 기준으로 `#506`은 종료 가능하다.
