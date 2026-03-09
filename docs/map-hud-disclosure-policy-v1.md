# Map HUD Disclosure Policy v1

## 목표
- 지도 본면, 현재 상태, 핵심 CTA가 먼저 읽히도록 설명성 surface를 기본 축약 상태로 유지한다.
- 설명을 없애지 않고, 사용자가 필요할 때만 명시적으로 펼치거나 guide sheet로 이동하게 만든다.

## 시작 전 정책
- 시작 전 helper는 `map.walk.startMeaning.card` 하나만 유지한다.
- 기본 상태는 `제목 + 한 줄 요약 + disclosure 버튼`만 노출한다.
- 사용자가 `map.walk.startMeaning.expand`를 눌렀을 때만 상세 본문을 펼친다.
- 펼친 상태에서는 `map.walk.startMeaning.collapse`로 즉시 접을 수 있어야 한다.
- 상세 guide sheet 재진입 CTA `map.walk.guide.reopen`은 펼친 상태에서만 노출한다.

## 산책 중 정책
- 산책 중 설명성 surface의 기본 상태는 `map.walk.activeValue.card` slim HUD다.
- 기본 상태는 제목, 상태 한 줄, 핵심 metric만 노출한다.
- top chrome 경쟁 요소가 없을 때만 `map.walk.activeValue.expand`로 inline detail을 펼칠 수 있다.
- inline detail 루트 식별자는 `map.walk.activeValue.detail.card`다.
- inline detail은 `map.walk.activeValue.collapse`로 즉시 닫을 수 있어야 한다.
- top chrome 경쟁 요소가 있을 때는 inline detail을 허용하지 않고, disclosure는 `guide sheet` 재진입으로 강등한다.

## overlay 우선순위
- top row: 날씨 pill, 시즌 pill, 설정 버튼
- 그 아래: walking slim HUD
- walking inline detail은 `banner / status overlay / season tile summary-detail`이 없을 때만 허용한다.
- 경쟁 요소가 생기면 walking inline detail은 자동으로 닫고, 설명 재진입은 guide sheet 경로만 유지한다.
- add-point button과 bottom control bar는 disclosure 여부와 관계없이 기존 하단 조작 계약을 유지한다.

## 닫기/복귀 규칙
- 시작 전 inline detail은 같은 카드 안에서 열고 닫는다.
- 산책 중 inline detail도 같은 top chrome stack 안에서 열고 닫는다.
- guide sheet는 기존 닫기 동작을 유지한다.
- guide sheet를 열기 전에는 inline detail을 먼저 정리한다.

## 회귀 기준
- `FeatureRegressionUITests/testFeatureRegression_MapStartMeaningDisclosureExpandsOnlyWhenRequested`
- `FeatureRegressionUITests/testFeatureRegression_MapWalkingHUDDisclosureExpandsOnlyWhenRequested`
- `swift scripts/map_hud_disclosure_policy_unit_check.swift`
