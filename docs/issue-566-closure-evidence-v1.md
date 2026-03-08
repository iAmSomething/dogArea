# Issue #566 Closure Evidence v1

## 대상
- issue: `#566`
- title: `산책을 제품의 기본 루프로 재정의하는 설명·정보 위계 정리`

## 구현 근거
- PR `#585`에서 홈/지도/산책 기록 기준의 `산책 중심` 정보 위계를 반영했다.
- PR `#586`에서 산책 시작 전/중/저장 직후 가치 흐름 설명을 연결했다.
- 근거 문서:
  - `docs/walk-primary-loop-information-hierarchy-v1.md`
  - `docs/walk-value-flow-onboarding-v1.md`

## DoD 판정
### 1. 홈/지도 기준 산책 중심의 제품 설명 위계가 정리된다
- 홈 상단에 `산책이 이 앱의 시작점` 카드가 들어가고, 실내 미션은 보조 흐름으로 내려갔다.
- 지도 시작 전 상태에 산책 의미 카드가 추가되어 `산책 시작` CTA가 단순 버튼이 아니라 의미 있는 시작점으로 읽히게 정리됐다.
- 산책 목록/상세도 `기록 허브`와 `이 산책이 남기는 것` 설명으로 같은 위계를 유지한다.
- 판정: `PASS`

### 2. 사용자는 미션보다 먼저 산책의 의미와 결과를 이해할 수 있다
- 산책 시작 전에는 `경로 / 영역 / 시간 / 포인트`가 기록된다는 설명이 먼저 나온다.
- 산책 저장 후에는 목록/상세/목표/미션으로 이어지는 후속 흐름이 같은 용어로 연결된다.
- 실내 미션은 `예외 상황의 보조 흐름`으로만 해석되게 문구가 정리됐다.
- 판정: `PASS`

### 3. 실내 미션은 예외/보조 플로우로 자연스럽게 읽힌다
- 홈 미션 프레젠테이션 서비스와 날씨 미션 상태 빌더가 모두 `보조`, `백업`, `예외 상황` 문맥으로 정렬됐다.
- 관련 가이드는 `산책 위에 얹힌 보조 시스템`이라는 표현을 유지한다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/walk_primary_loop_information_hierarchy_unit_check.swift`
  - `swift scripts/walk_value_flow_onboarding_unit_check.swift`
  - `swift scripts/issue_566_closure_evidence_unit_check.swift`
- 회귀 UI 테스트
  - `FeatureRegressionUITests.testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop`
  - `FeatureRegressionUITests.testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards`
  - `FeatureRegressionUITests.testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy`
  - `FeatureRegressionUITests.testFeatureRegression_MapWalkValueGuideAutoPresentsOnFirstVisit`
  - `FeatureRegressionUITests.testFeatureRegression_MapWalkValueFlowExplainsDuringAndAfterSaving`

## 결론
- `#566`의 요구사항은 저장소 기준 구현과 검증 근거가 모두 확보됐다.
- 이 문서를 기준으로 `#566`은 종료 가능하다.
