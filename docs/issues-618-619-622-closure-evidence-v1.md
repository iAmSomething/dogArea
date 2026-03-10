# Issues #618 #619 #622 Closure Evidence v1

## 대상
- issues: `#618`, `#619`, `#622`
- theme: `지도 설명 HUD disclosure`, `상단 slim HUD`, `산책 기록 탭 top safe area 재발 방지`

## 구현 근거
### #618 설명 HUD disclosure 정책 재설계
- `#618`에서 시작 전 helper와 산책 중 slim HUD를 모두 `기본 축약 + 필요 시 확장` 원칙으로 정리했다.
- 시작 전 helper는 `map.walk.startMeaning.card`의 compact summary로 유지되고, 상세 본문은 명시적으로 펼칠 때만 열린다.
- 산책 중 설명성 surface는 `map.walk.activeValue.card` slim HUD를 기본으로 유지하고, 경쟁 overlay가 없을 때만 inline detail을 허용한다.
- 근거 문서:
  - `docs/map-hud-disclosure-policy-v1.md`

### #619 safe area 아래 상단 slim HUD 재배치
- `#619`에서 산책 중 핵심 정보를 하단 large helper가 아니라 safe area 아래 top chrome band의 slim HUD로 이동시켰다.
- 하단 control bar는 조작 전용, 상단 HUD는 상태 전용으로 역할을 분리했다.
- 근거 문서:
  - `docs/map-top-slim-hud-safearea-v1.md`

### #622 산책 기록 탭 상단 safe area 재발 방지
- `#622`에서 non-map 루트 상단 예약을 `safeAreaInset(edge: .top)` 기준 계약으로 고정했다.
- 산책 기록 화면은 큰 임시 top padding 대신 내부 리듬만 책임지고, sticky section header까지 같은 예약 안에서 유지되게 정리했다.
- 근거 문서:
  - `docs/walklist-top-safearea-contract-v1.md`

## DoD 판정
### 1. #618 설명 surface가 기본 상태에서 지도를 가리지 않는다
- 시작 전 설명 카드는 항상 펼쳐진 대형 카드가 아니라 compact summary 상태를 기본값으로 가진다.
- 산책 중 설명은 slim HUD의 한 줄 상태 요약이 기본이며, 자세한 내용은 명시적 disclosure 이후에만 열린다.
- 판정: `PASS`

### 2. #619 산책 중 핵심 정보와 조작 레이어가 역할별로 분리된다
- 상단 top chrome band는 경과 시간/영역/포인트 같은 상태를 읽는 slim HUD를 담당한다.
- 하단 control deck은 시작/종료/영역 추가 같은 조작만 담당한다.
- 상하단이 서로 같은 정보를 중복 노출하지 않는다.
- 판정: `PASS`

### 3. #622 산책 기록 탭의 상단 충돌이 공통 계약 기준으로 막힌다
- 산책 기록 화면은 루트 scaffold가 top reservation을 맡고, 화면 내부는 `contentTopPadding` 수준의 리듬만 유지한다.
- sticky section header도 같은 reservation 안에 머물며 status bar와 충돌하지 않는다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/map_hud_disclosure_policy_unit_check.swift`
  - `swift scripts/map_top_slim_hud_safearea_unit_check.swift`
  - `swift scripts/walklist_top_safearea_contract_unit_check.swift`
  - `swift scripts/issues_618_619_622_closure_evidence_unit_check.swift`
- 회귀 UI 테스트
  - `FeatureRegressionUITests.testFeatureRegression_MapStartMeaningDisclosureExpandsOnlyWhenRequested`
  - `FeatureRegressionUITests.testFeatureRegression_MapWalkingHUDDisclosureExpandsOnlyWhenRequested`
  - `FeatureRegressionUITests.testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls`
  - `FeatureRegressionUITests.testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar`

## 결론
- `#618`, `#619`, `#622`는 모두 구현과 회귀 기준이 저장소에 반영된 상태다.
- 이 문서를 기준으로 세 이슈를 함께 닫아도 된다.
