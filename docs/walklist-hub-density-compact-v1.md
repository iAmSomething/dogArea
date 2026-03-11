# WalkList Hub Density Compact v1

## 목표
- 산책 기록 상단 허브를 onboarding 카드처럼 길게 설명하지 않고, 짧은 정보 허브 2장으로 정리한다.
- `기본 행동`, `선택 기준` 카드의 내부 패딩과 정렬 리듬을 최근 요약/달력 카드와 비슷하게 맞춘다.

## 적용 기준
- 상단 허브는 `TitleTextView -> 기본 행동 카드 -> 최근 요약 -> 기준 카드 -> 달력` 순서를 유지한다.
- `기본 행동` 카드는 다음만 항상 보여준다.
  - badge
  - 짧은 제목 1줄
  - 설명 1~2줄
  - 보조 흐름 문구 1~2줄
- `선택 기준` 카드는 다음만 항상 보여준다.
  - mode badge
  - 제목 1줄
  - 설명 1~2줄
  - 반려견 칩
  - helper 1~2줄
  - `기준으로 돌아가기` CTA는 필요한 경우만 유지

## 밀도 계약
- `WalkListPrimaryLoopSummaryCardView`
  - title size `18`
  - body size `12`
  - secondary size `11`
  - vertical spacing `8`
- `WalkListContextSummaryCardView`
  - title size `18`
  - body size `12`
  - helper size `11`
  - vertical spacing `10`
- 긴 onboarding 문구는 유지하지 않는다.
- helper 문구는 필요한 경우 2줄까지 허용하되 `...`로 자르지 않는다.

## 금지
- `홈 목표와 시즌 흐름을 다시 읽는 기준` 같은 장문 설명 재도입 금지
- context 카드에서 칩/CTA 제거 금지
- primary/context 카드가 최근 요약 카드보다 시각적으로 더 무겁게 커지는 변경 금지

## 회귀 기준
- 상단 허브는 `walklist.primaryLoop.card`, `walklist.summary`, `walklist.context`를 함께 유지한다.
- UI 회귀:
  - `FeatureRegressionUITests/testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards`
  - `FeatureRegressionUITests/testFeatureRegression_WalkListHeaderCardsStayCompactWithoutVerboseOnboardingCopy`
