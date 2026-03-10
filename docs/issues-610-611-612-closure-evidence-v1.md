# Issues #610 #611 #612 Closure Evidence v1

## 대상
- issues: `#610`, `#611`, `#612`
- theme: `지도 시작 deck`, `홈 기본 루프 카드`, `산책 중 진행 HUD`의 정보 밀도와 위계 정리

## 구현 근거
### #610 산책 시작 deck 위치·크기·정보 밀도 재설계
- `#609`에서 시작 전 의미 카드를 deck 안의 compact helper로 축약했다.
- `#620`에서 idle/walking control bar footprint budget과 anchored bar 밀도를 정리했다.
- 근거 문서:
  - `docs/map-start-meaning-card-compact-v1.md`
  - `docs/map-bottom-controller-anchored-density-v1.md`

### #611 홈 산책 기본 루프 설명 카드 위계 재설계
- 이번 묶음에서 홈 기본 루프 카드를 `compact summary + explicit guide sheet` 구조로 전환했다.
- 장문 pillar 설명은 상시 본문에서 제거하고 `설명 보기` sheet로 이동했다.
- 근거 문서:
  - `docs/walk-primary-loop-information-hierarchy-v1.md`

### #612 산책 중 진행 설명 카드 compact HUD 전환
- `#618`에서 설명 HUD의 기본 축약/명시적 disclosure 정책을 도입했다.
- `#619`에서 walking 진행 정보를 safe area 아래 top slim HUD로 올리고 하단 control deck와 분리했다.
- 근거 문서:
  - `docs/map-hud-disclosure-policy-v1.md`
  - `docs/map-top-slim-hud-safearea-v1.md`

## DoD 판정
### 1. #610 시작 deck이 tab bar 바로 위 compact control 영역으로 읽힌다
- idle 시작 deck은 CTA 중심의 compact control bar로 축소됐다.
- 의미 설명은 deck 내부 compact helper 카드로만 유지되고, 지도 본면을 가리는 대형 panel이 사라졌다.
- anchored bottom controller contract와 add-point separation contract가 함께 유지된다.
- 판정: `PASS`

### 2. #611 홈 상단이 현재 상태/요약 우선으로 읽히고 설명은 명시적 진입으로 내려간다
- 홈 기본 루프 카드는 상시 장문 onboarding 카드가 아니라 compact summary 카드로 바뀌었다.
- 장문 설명과 pillar 3개는 `home.walkPrimaryLoop.openGuide`로 여는 sheet에만 있다.
- 홈 상단 1스크린은 인사말/반려견 문맥/compact summary 이후에 주간·시즌·날씨 정보가 이어지는 구조를 유지한다.
- 판정: `PASS`

### 3. #612 산책 중 진행 정보가 지도 -> 조작 -> 최소 HUD 위계로 정리된다
- walking 진행 정보는 하단 large helper가 아니라 safe area 아래 slim HUD로 유지된다.
- 기본 상태는 축약이며, 자세한 설명은 명시적 disclosure 이후에만 열린다.
- 하단 control deck은 조작 전용, 상단 slim HUD는 상태 전용으로 분리됐다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/walk_primary_loop_information_hierarchy_unit_check.swift`
  - `swift scripts/map_start_meaning_card_compact_unit_check.swift`
  - `swift scripts/map_hud_disclosure_policy_unit_check.swift`
  - `swift scripts/map_top_slim_hud_safearea_unit_check.swift`
  - `swift scripts/issues_610_611_612_closure_evidence_unit_check.swift`
- 회귀 UI 테스트
  - `FeatureRegressionUITests.testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop`
  - `FeatureRegressionUITests.testFeatureRegression_HomeWalkPrimaryLoopCardStaysCompactAndOpensGuideOnDemand`
  - `FeatureRegressionUITests.testFeatureRegression_MapStartMeaningDisclosureExpandsOnlyWhenRequested`
  - `FeatureRegressionUITests.testFeatureRegression_MapWalkingHUDDisclosureExpandsOnlyWhenRequested`
  - `FeatureRegressionUITests.testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls`
  - `FeatureRegressionUITests.testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactAtRest`

## 결론
- `#610`, `#611`, `#612`는 같은 정보 위계 정리 작업으로 묶어 종료 가능한 상태다.
- 이 문서를 기준으로 세 이슈를 함께 닫아도 된다.
