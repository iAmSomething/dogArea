# Rival Top Safe Area Contract v1

## 목적
- 라이벌 탭 첫 진입 시 제목, 부제, 첫 상태 배지 행이 status bar와 겹치지 않도록 레이아웃 계약을 고정한다.
- 작은 화면, 긴 부제, Dynamic Type 확대에서도 라이벌 헤더가 안정적으로 감싸지도록 한다.
- 화면별 큰 `padding(.top)` 땜질이 아니라 공통 scaffold와 헤더 컴포넌트 책임을 분리한다.

## 책임 분리

### 공통 scaffold 책임
- 탭 루트 화면의 상단 safe area 예약과 고정 top chrome 삽입은 `AppTabScaffold`가 맡는다.
- 라이벌 탭은 비지도 탭 공통 계약 `AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding`을 그대로 따른다.
- status bar 충돌 방지는 루트 scroll layout과 `nonMapRootTopChrome` 단계에서 해결한다.

### 라이벌 헤더 책임
- `RivalTabView`의 헤더 섹션은 safe area inset을 직접 계산하지 않는다.
- 제목/부제는 큰 글자 크기와 긴 문구에서도 줄바꿈과 세로 확장을 안정적으로 처리한다.
- 첫 상태 배지 행은 헤더 부제 아래에 분리된 리듬으로 배치된다.
- 제목/부제/배지 행은 접근성 식별자를 제공해 회귀 테스트가 실제 프레임을 검증할 수 있어야 한다.
- 제목/부제/첫 상태 배지 행은 scroll content 밖 고정 chrome 안에 함께 있어야 한다.

### 공통 TitleTextView 책임
- `TitleTextView`는 루트 safe area를 소유하지 않는다.
- 대신 large title 계열 화면에서 multiline title/subtitle과 Dynamic Type을 안정적으로 처리한다.
- 다른 `TitleTextView` 기반 화면도 같은 줄바꿈 계약을 공유한다.

## 구현 계약
- `RivalTabView`의 첫 커스텀 헤더와 첫 상태 배지 행은 `nonMapRootTopChrome(bottomSpacing: 12)`으로 scroll content 밖 상단에 고정한다.
- 라이벌 화면은 전용 `contentTopPadding` enum을 다시 두지 않는다.
- 라이벌 루트 scroll layout은 아래 형태를 유지한다.

```swift
.appTabRootScrollLayout(
    extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding,
    topSafeAreaPadding: 0
)
.nonMapRootTopChrome(bottomSpacing: 12) { ... }
```

- 헤더 텍스트는 다음을 유지한다.
  - 제목: `lineLimit(2)` + `fixedSize(horizontal: false, vertical: true)`
  - 부제: `lineLimit(3)` + `fixedSize(horizontal: false, vertical: true)`
- 첫 상태 배지 행은 `rival.header.badges` 식별자로 회귀 테스트가 프레임을 검증할 수 있어야 한다.

## 금지 사항
- 라이벌 화면 최상단에 큰 상수 `padding(.top)` 하나만 더하는 방식
- 헤더 폰트를 강제로 줄여서 겹침을 숨기는 방식
- 공통 scaffold 기본값 대신 라이벌 전용 root top inset override를 다시 넣는 방식

## 회귀 검증
- 기능 회귀:
  - `FeatureRegressionUITests/testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle`
- 정적 계약:
  - `swift scripts/rival_top_safearea_contract_unit_check.swift`
- 문서 매핑:
  - `docs/ui-regression-matrix-v1.md`의 `FR-RIVAL-003`

## 기대 결과
- 라이벌 첫 진입 시 제목/부제/배지 행이 status bar 아래에 위치한다.
- 긴 부제와 큰 글자 크기에서도 헤더가 겹치지 않는다.
- 다른 `TitleTextView` 기반 화면도 multiline title/subtitle 계약을 함께 공유한다.
- 스크롤해도 라이벌 헤더와 첫 상태 배지 행은 본문과 분리된 상단 chrome 위치를 유지한다.
