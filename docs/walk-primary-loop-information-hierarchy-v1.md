# Walk Primary Loop Information Hierarchy v1

## 목적
- 홈과 지도에서 사용자가 먼저 `이 앱의 기본 행동은 산책`이라는 사실을 이해하게 만든다.
- 산책 시작 전/중/후/기록 화면의 설명이 서로 충돌하지 않게 연결한다.
- 실내 미션은 삭제하지 않고 `예외 상황의 보조 흐름`으로 명확히 내린다.

## 제품 결정
- 홈 상단에는 `산책이 이 앱의 시작점이에요` 카드가 먼저 나온다.
- 이 카드는 최소 4가지를 직접 설명한다.
  - 산책을 시작하면 경로와 영역이 기록된다.
  - 산책 시간과 기록이 누적된다.
  - 산책 결과가 목표, 미션, 시즌 해석에 연결된다.
  - 실내 미션은 악천후/예외 상황에서만 열리는 보조 흐름이다.
- 홈의 실내 미션 영역은 `보조 흐름` 라벨과 함께 노출한다.
- 지도 시작 전 상태에는 `산책이 바로 기록이 됩니다` 설명 카드를 둔다.
- 지도 산책 중 상태 문구는 `산책 진행 중`이 아니라 `경로·영역 기록 중`으로 읽히게 한다.
- 산책 종료 알럿은 저장 후 종료 시 기록이 목표/시즌으로 이어진다는 점을 직접 설명한다.
- 산책 목록 헤더는 `기록 허브`로 읽히도록 바꾸고, 상세 화면에는 `이 산책이 남기는 것` 요약을 둔다.

## 화면별 위계
### 홈
1. 인사말
2. 선택 반려견 문맥
3. 산책 기본 루프 설명 카드
4. 주간/시즌/날씨 정보
5. 실내 미션 보조 영역

### 지도
1. 산책 의미 설명 카드
2. 반려견 문맥 카드
3. 산책 시작 CTA
4. 산책 중에는 기록 진행 상태와 현재 영역

### 산책 기록
1. 산책이 기록 허브라는 설명
2. 요약/필터/캘린더
3. 상세 화면에서 해당 산책이 남긴 가치 설명

## 자동 검증
- `FeatureRegressionUITests/testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop`
- `FeatureRegressionUITests/testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards`
- `FeatureRegressionUITests/testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy`
- `swift scripts/walk_primary_loop_information_hierarchy_unit_check.swift`
