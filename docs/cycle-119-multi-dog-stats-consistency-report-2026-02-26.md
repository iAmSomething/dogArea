# Cycle 119 Report — Multi-Dog Stats Consistency v1 (2026-02-26)

## 1. Scope
- Target issue: #119
- Goal: Home/WalkList 집계를 선택 반려견 컨텍스트 기준으로 일관화

## 2. Documentation First
- Updated `docs/multi-dog-context-sync-v1.md`
  - 선택 반려견 통계 집계 규칙(v1.1) 추가
  - 레거시 untagged 세션 fallback 규칙 추가
- Updated `docs/release-regression-checklist-v1.md`
  - 반려견 전환 시 Home/WalkList 재집계 체크 항목 추가

## 3. Implementation
1. Session metadata tagging
- Updated `dogArea/Source/UserdefaultSetting.swift`
  - `WalkSessionMetadata.petId` 추가
  - `WalkSessionMetadataStore.set(..., petId:)` 확장
  - `petId(sessionId:)` 조회 API 추가

2. Map save path update
- Updated `dogArea/Views/MapView/MapViewModel.swift`
  - 세션 저장 시 `selectedPetId`를 metadata에 기록
  - 복구 세션 자동/수동 종료 경로에서도 snapshot `selectedPetId` 기록

3. Home selected-pet aggregation
- Updated `dogArea/Views/HomeView/HomeViewModel.swift`
  - 전체 세션 캐시(`allPolygons`)와 선택 반려견 필터 집계 분리
  - `applySelectedPetStatistics`/`filteredPolygons` 추가
  - 선택 반려견 변경 이벤트에서 즉시 재집계
  - 레거시 데이터(세션 petId 미기록)만 있는 경우 전체 집계 fallback

4. WalkList selected-pet filtering
- Updated `dogArea/Views/WalkListView/WalkListViewModel.swift`
  - 전체 목록 캐시(`allWalkingDatas`)와 선택 반려견 필터 목록 분리
  - `applySelectedPetFilter` 추가
  - 선택 반려견 변경 이벤트에서 즉시 목록 재필터링
  - 레거시 데이터 fallback 적용

5. Unit check update
- Updated `scripts/multi_dog_context_sync_unit_check.swift`
  - 통계 집계 규칙/세션 pet tagging/필터 로직 검증 항목 추가

## 4. Unit Tests
- `swift scripts/multi_dog_context_sync_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/profile_repository_transition_unit_check.swift` -> PASS
- `swift scripts/userinfo_supabase_sync_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS
- `swift scripts/swift_stability_unit_check.swift` -> PASS

## 5. Outcome
- 선택 반려견 전환 시 Home/WalkList가 동일 기준으로 즉시 동기화
- 과거 데이터 호환을 위한 fallback으로 기존 사용자 기록 가시성 유지
