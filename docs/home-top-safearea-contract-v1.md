# Home Top Safe Area Contract v1

## 목적
- 홈 탭 첫 진입 시 상단 인사말, 레벨 배지, 첫 카드가 status bar와 겹치지 않도록 레이아웃 계약을 고정한다.
- 작은 화면, 긴 사용자명/반려견 이름, Dynamic Type 확대에서도 홈 헤더가 안정적으로 감싸지도록 한다.
- 단순 화면별 `padding(.top)` 땜질이 아니라 공통 scaffold와 홈 헤더의 책임을 분리한다.

## 책임 분리

### 공통 scaffold 책임
- 탭 루트 화면의 상단 safe area 예약과 고정 top chrome 삽입은 `AppTabScaffold`가 맡는다.
- 홈은 비지도 탭 공통 계약 `AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding`을 그대로 따른다.
- status bar 충돌 방지는 루트 scroll layout과 `nonMapRootTopChrome` 단계에서 해결한다.

### 홈 헤더 책임
- `HomeHeaderSectionView`는 상단 inset을 직접 계산하지 않는다.
- 긴 텍스트와 큰 글자 크기에서도 줄바꿈과 세로 확장을 안정적으로 처리한다.
- 제목/부제/배지는 접근성 식별자를 제공해 회귀 테스트가 실제 프레임을 검증할 수 있어야 한다.

## 구현 계약
- `HomeView`의 첫 커스텀 헤더는 `nonMapRootTopChrome`으로 scroll content 밖 상단에 고정한다.
- 홈은 화면 전용 `contentTopPadding` enum을 다시 두지 않는다.
- 홈 루트 scroll layout은 빈 상단 inset을 추가로 만들지 않도록 `topSafeAreaPadding: 0`을 사용한다.

```swift
.appTabRootScrollLayout(
    extraBottomPadding: AppTabLayoutMetrics.defaultScrollExtraBottomPadding,
    topSafeAreaPadding: 0
)
.nonMapRootTopChrome { ... }
```

- 헤더 텍스트는 다음을 유지한다.
  - 제목: `lineLimit(2)` + `fixedSize(horizontal: false, vertical: true)`
  - 부제: `lineLimit(3)` + `fixedSize(horizontal: false, vertical: true)`

## 금지 사항
- 홈 화면 최상단에 큰 상수 `padding(.top)` 하나만 더하는 방식
- 헤더 폰트를 임의 축소해서 겹침을 숨기는 방식
- 공통 scaffold 기본값 대신 홈 전용 root top inset override를 다시 넣는 방식

## 회귀 검증
- 기능 회귀:
  - `FeatureRegressionUITests/testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames`
- 정적 계약:
  - `swift scripts/home_top_safearea_contract_unit_check.swift`
- 문서 매핑:
  - `docs/ui-regression-matrix-v1.md`의 `FR-HOME-001`

## 기대 결과
- 홈 첫 진입 시 헤더 타이틀/부제가 status bar 아래에 위치한다.
- 긴 사용자명/반려견 이름과 큰 글자 크기에서도 헤더가 겹치지 않는다.
- 홈 복귀/스크롤/상세 복귀 뒤에도 상단 위치 기준이 흔들리지 않는다.
- 스크롤 중에도 홈 헤더는 본문과 분리된 상단 chrome 위치를 유지한다.
