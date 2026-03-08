# WalkList Month Calendar Hub v1 (Issue #567)

## 목표
- 산책 목록 탭 상단 허브를 `날짜 기반 탐색 허브`로 강화한다.
- 사용자가 리스트를 보기 전에 `언제 걸었는지`를 월 단위로 빠르게 읽고, 특정 날짜 기록으로 즉시 진입할 수 있게 한다.

## 배치 원칙
- 캘린더는 `WalkListDashboardHeaderView` 안쪽의 세 번째 핵심 surface로 배치한다.
- 구조 순서:
  1. 타이틀/요약 메트릭
  2. 필터 문맥 카드(반려견 기준)
  3. 월별 산책 캘린더 카드
- 기존 guest card / empty state / section list는 유지한다.

## 날짜 마킹 규칙
- 해당 날짜에 산책 기록이 1건 이상 있으면 마킹한다.
- 1건은 `점(dot)`으로 표시한다.
- 2건 이상은 `숫자 배지(count badge)`로 표시한다.
- 자정을 넘긴 산책은 걸친 모든 날짜에 표시한다.
- 날짜 계산은 사용자의 로컬 타임존과 로컬 캘린더 경계를 기준으로 한다.
- 날짜 집계는 `HomeWeeklyStatisticsService.dayStartsCovered(by:calendar:)`를 재사용한다.

## 상호작용 정책
- 날짜 탭 시 그 날짜를 커버한 세션만 즉시 리스트에 남긴다.
- 선택된 같은 날짜를 다시 탭하면 필터를 해제한다.
- 선택 상태일 때는 `월 전체 보기` CTA를 함께 노출한다.
- 월 이동(`이전 달`, `다음 달`) 시 현재 날짜 필터는 해제한다.
- 날짜 필터가 활성화되면 섹션 헤더는 `선택 날짜 기록` 단일 섹션으로 전환한다.
- 날짜 탭은 리스트 자동 스크롤이 아니라 `즉시 필터` 정책을 채택한다.

## 빈 상태 / 게스트 상태 정책
- 현재 스코프 기록이 0건이면 큰 빈 달력을 그리지 않는다.
- 대신 `첫 산책을 저장하면 날짜가 채워진다`는 기대 형성 문구를 담은 compact empty card를 보여준다.
- 게스트 상태여도 로컬 산책 기록이 있으면 캘린더는 그대로 렌더링한다.
- 게스트 여부는 캘린더 렌더링을 막는 조건이 아니다. 데이터 소스가 로컬 저장소이기 때문이다.

## 성능 정책
- 캘린더 날짜 마킹은 View body에서 직접 계산하지 않는다.
- `WalkListCalendarPresentationService`가 날짜별 record snapshot을 한 번 계산하고, ViewModel은 그 snapshot을 재사용한다.
- 반려견 스코프 변경 / 타임존 변경 / 일자 변경 / 월 이동 / 수동 새로고침 때만 다시 계산한다.
- 최초 표시 월은 다음 규칙을 따른다.
  - 현재 달에 기록이 있으면 현재 달
  - 현재 달에 기록이 없고 기록이 있으면 `가장 최근 산책이 있는 달`
  - 기록이 없으면 현재 달

## 접근성
- 날짜 셀은 최소 높이 `44pt` 이상을 유지한다.
- 날짜 셀마다 접근성 라벨로 `M월 d일, 산책 N건` 문구를 제공한다.
- 선택 요약/해제 CTA는 별도 접근성 식별자를 가진다.

## 회귀 검증
- `FeatureRegressionUITests/testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards`
- `FeatureRegressionUITests/testFeatureRegression_WalkListCalendarSelectionFiltersToChosenDate`
- `scripts/walklist_month_calendar_hub_unit_check.swift`
