# Cycle 136 Report — Walk Session Pet Canonicalization v1 (2026-02-26)

## 1. Scope
- Target issue: #136
- Goal: 산책 세션 반려견 귀속을 sidecar 의존에서 CoreData canonical 필드로 전환

## 2. Documentation First
- Updated `docs/multi-dog-context-sync-v1.md`
  - v1.2 canonicalization 규칙 추가
- Updated `docs/release-regression-checklist-v1.md`
  - 신규 산책 저장 canonical pet_id 검증 항목 추가

## 3. Implementation
1. CoreData canonical field
- Updated `dogArea/dogArea.xcdatamodeld/dogArea.xcdatamodel/contents`
  - `PolygonEntity.petId` 속성 추가

2. Save/read/backfill path
- Updated `dogArea/Source/CoreDataProtocol.swift`
  - 저장 시 `Polygon.petId -> PolygonEntity.petId` 고정 저장
  - 최초 fetch 시 metadata 기반 누락 petId 백필(`backfillPolygonPetIdsFromMetadataIfNeeded`)
- Updated `dogArea/Source/CoreDataDTO.swift`
  - Supabase DTO 변환 시 canonical `polygon.petId/entity.petId` 우선 사용
  - `PolygonEntity.toPolygon()`에 canonical petId 반영

3. Session creation/finalization
- Updated `dogArea/Views/MapView/MapModel.swift`
  - `Polygon.petId` 필드 추가
- Updated `dogArea/Views/MapView/MapViewModel.swift`
  - 산책 시작/종료/복구 종료 경로에서 `polygon.petId` 설정
  - outbox sync는 `selectedPetId`가 아닌 `polygon.petId` 기준으로 전송

4. Stats/list filtering switch
- Updated `dogArea/Views/HomeView/HomeViewModel.swift`
  - 필터 기준을 `polygon.petId`로 전환
- Updated `dogArea/Views/WalkListView/WalkListModel.swift`
  - `WalkDataModel.petId` 보존
- Updated `dogArea/Views/WalkListView/WalkListViewModel.swift`
  - 목록 필터 기준을 `walkData.petId`로 전환

5. Unit checks
- Added `scripts/walk_session_pet_canonicalization_unit_check.swift`
- Updated `scripts/multi_dog_context_sync_unit_check.swift` (canonical 기준 반영)

## 4. Unit Tests
- `swift scripts/walk_session_pet_canonicalization_unit_check.swift` -> PASS
- `swift scripts/multi_dog_context_sync_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/walk_sync_consistency_outbox_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS
- `swift scripts/swift_stability_unit_check.swift` -> PASS

## 5. Outcome
- 신규 산책 세션은 canonical `petId`를 CoreData 본체에 저장
- Home/WalkList 통계/필터는 canonical 필드 기준으로 동작
- sidecar는 레거시 백필 용도로 축소
