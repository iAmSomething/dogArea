# WalkList Calendar Weekend/Holiday Semantic v1

## 목표
- 월별 산책 캘린더에서 토요일, 일요일, 공휴일 의미를 빠르게 읽을 수 있게 한다.
- weekday header와 실제 날짜 셀이 같은 semantic 체계를 쓰게 만든다.

## semantic 체계
- `weekday`: 기본 slate 계열
- `saturday`: 파랑 계열
- `sunday`: 빨강 계열
- `holiday`: 빨강 계열, 일요일과 같은 family를 쓰되 공휴일 데이터가 있으면 이 tone이 우선한다

## 공휴일 소스 정책
- 공휴일 데이터가 있는 런타임에서는 `holidayName(for:calendar:)`가 이름을 돌려주면 `holiday` tone을 적용한다.
- 공휴일 데이터가 없는 런타임에서는 empty provider가 항상 `nil`을 반환한다.
- 이 fallback에서는 토요일/일요일 weekend 규칙만 적용한다.
- 한국 공휴일 날짜를 임시 상수로 박아 넣지 않는다.

## 우선순위
1. `holiday`
2. `sunday`
3. `saturday`
4. `weekday`

- 위 우선순위는 텍스트 tone 기준이다.
- `selected/today는 배경·보더`, semantic 색은 텍스트 tone으로 유지한다.
- `interactive` 여부는 같은 tone 안에서 채도/명도만 바꾸고 hue 의미는 바꾸지 않는다.

## 접근성
- 날짜/산책 건수 설명을 기본으로 유지한다.
- 토요일/일요일은 각각 `토요일`, `일요일` semantic을 라벨에 덧붙인다.
- 공휴일 소스가 있으면 `holidayName + 공휴일`을 우선 노출한다.
- weekday header도 같은 semantic을 accessibility label로 노출한다.

## 회귀 기준
- header와 day cell 모두 `WalkListCalendarSemanticTone`을 통해 색을 결정한다.
- `FR-WALK-004A`
  - `FeatureRegressionUITests/testFeatureRegression_WalkListCalendarWeekendSemanticLabelsStayConsistent`
