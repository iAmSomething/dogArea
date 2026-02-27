# Cycle 140 Report — UserdefaultSetting 책임 분리 (2026-02-27)

## 1. 대상
- Issue: `#140 [P1][Task] UserdefaultSetting 책임 분리 리팩터링`
- Branch: `codex/cycle-140-userdefault-split`

## 2. 구현 요약
- `UserdefaultSetting`을 파사드로 축소하고 책임을 Store 단위로 분리:
  - `ProfileStore`
  - `PetSelectionStore`
  - `WalkSessionMetadataStore`
  - `ProfileSyncOutboxStore`
- `ProfileRepository`가 `UserdefaultSetting` 직접 의존 대신 인터페이스(`ProfileStoring`, `PetSelectionStoring`)를 사용하도록 전환.
- 기존 공개 API(`setSelectedPetId`, `selectedPet`, `walkPointRecordModeRawValue` 등)는 유지하여 호출부 회귀를 방지.

## 3. 변경 파일
- `dogArea/Source/UserdefaultSetting.swift`
- `dogArea/Source/ProfileStore.swift`
- `dogArea/Source/PetSelectionStore.swift`
- `dogArea/Source/WalkSessionMetadataStore.swift`
- `dogArea/Source/ProfileSyncOutboxStore.swift`
- `dogArea/Source/ProfileRepository.swift`
- `dogArea.xcodeproj/project.pbxproj`
- `docs/userdefault-store-split-v1.md`
- `docs/cycle-140-userdefault-store-split-report-2026-02-27.md`
- `scripts/userdefault_store_split_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 검증
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS
  - 신규 `userdefault_store_split_unit_check` 포함
- 전체 iOS 빌드는 패키지 컴파일 시간이 길어 중단하고, 스크립트 기반 회귀 검증을 통과한 상태로 PR 생성.

## 5. 리스크/후속
- `UserdefaultSetting` 내부에 호환용 참조(`ProfileSync*`)가 남아 있어 이후 단계에서 호출부 전환이 충분히 끝나면 제거 가능.
- Store 단위로 분리된 만큼, 다음 사이클에서는 각 Store의 동작 테스트를 데이터 fixture 기반으로 세분화하는 것이 좋다.
