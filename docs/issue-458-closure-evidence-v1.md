# Issue #458 Closure Evidence v1

## 대상
- issue: `#458`
- title: `[Home/Weather UX] 반려견 정보 기반 산책 주의사항 더보기 서브뷰 추가`

## 구현 근거
- 구현 PR: `#593`
- 선행 구현 커밋:
  - `1f7acd4 feat: add home weather pet guidance sheet`
  - `e94a39c feat: enrich home weather guidance detail (#593)`
- 핵심 문서:
  - `docs/home-weather-pet-guidance-sheet-v1.md`
- 핵심 구현 파일:
  - `dogArea/Source/Domain/Home/Services/HomeWeatherWalkGuidanceService.swift`
  - `dogArea/Views/HomeView/HomeSubView/Presentation/HomeWeatherGuidanceSheetView.swift`
  - `dogArea/Views/HomeView/HomeView.swift`
  - `dogArea/Views/HomeView/HomeViewModel.swift`

## DoD 판정
### 1. 홈 날씨 카드에서 진입 가능한 더보기 시트가 존재함
- 홈 뷰가 `HomeWeatherGuidanceSheetView`를 `sheet.home.weatherGuidance` 식별자로 표시한다.
- 시트 진입 CTA는 `home.weather.more` 접근성 식별자를 통해 고정돼 있다.
- 판정: `PASS`

### 2. 날씨 + 반려견 프로필 조합 규칙이 행동 가이드 중심으로 구성됨
- `HomeWeatherWalkGuidanceService`가 체감 온도, 강수, 바람, 공기질, 연령, 활동량, 체형 추정 근거를 조합한다.
- 시트는 `오늘 추천`, `이렇게 판단했어요`, `오늘 산책 시 주의`, `산책 권장 방식`, `실내 대체 추천` 순서로 행동 가이드를 노출한다.
- 판정: `PASS`

### 3. 최소 3개 이상 상황별 가이드 규칙이 적용됨
- 저온, 강수/강풍, 고온/고습, 공기질 악화, 고위험 악천후/실내 대체 우선 규칙이 문서와 서비스에 모두 존재한다.
- 소형견/노령견/유년기 반려견은 보수적 규칙을 추가 적용한다.
- 판정: `PASS`

### 4. 반려견 프로필 정보가 부족해도 안전한 fallback이 유지됨
- 활성 반려견 없음, 연령/견종 정보 누락, 관측값 부족 각각에 대한 fallback 정책이 별도로 정의돼 있다.
- fallback이어도 빈 화면이 아니라 동일한 3개 행동 가이드 섹션을 유지한다.
- 판정: `PASS`

### 5. 과장 없는 제품 카피 톤과 회귀 검증이 확보됨
- 문서가 의료 판단형 카피를 금지하고 제품 안전 가이드 톤을 명시한다.
- 정적 체크와 UI 회귀 테스트가 이미 저장소 게이트에 편입돼 있다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/home_weather_pet_guidance_unit_check.swift`
  - `swift scripts/issue_458_closure_evidence_unit_check.swift`
- UI 회귀
  - `FeatureRegressionUITests.testFeatureRegression_HomeWeatherGuidanceSheetShowsActionableFallbackAndSections`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#458`의 요구사항은 구현, 문서, 회귀 체크 근거까지 확보됐다.
- 이 문서를 기준으로 `#458`은 종료 가능하다.
