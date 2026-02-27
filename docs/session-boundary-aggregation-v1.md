# Session Boundary Aggregation v1 (Issue #153)

## 1. 목적
- 자정/주간 경계를 가로지르는 산책 세션을 통계 집계에서 정확히 분할한다.
- 원본 세션 엔터티(`Polygon`)는 유지하고 집계 계층에서만 분할 계산을 적용한다.

## 2. 분할 규칙
- 세션 구간: `start = createdAt`, `end = createdAt + walkingTime`
- 분할 단위: 사용자 로컬 타임존의 캘린더 경계(일/주)
- 분배 방식: 세션이 구간과 겹치는 `overlapSeconds / sessionDuration` 비율로 `walkingArea`, `walkingTime`을 비례 배분
- `walkingTime <= 0`인 레거시 세션은 시작 시점 기준으로 단일 구간에 100% 귀속

## 3. 집계 적용 범위
- 홈의 `이번 주 산책한 영역`
- 홈의 `이번 주 산책 횟수` (주간 구간과 overlap 된 세션 수)
- 홈 달력의 산책 날짜 표시 (세션이 걸친 모든 날짜 표시)

## 4. 타임존 변경 처리
- 이벤트: `NSSystemTimeZoneDidChange`, `NSCalendarDayChanged`
- 정책: 타임존 변경 시 과거 집계 재해석 없이, 이후 계산 시점부터 현재 타임존으로 집계
- UX: 홈 상단에 재집계 안내 메시지 표시

## 5. 전날/오늘 분할 기여 노출
- 기준 경계: `todayStart` (현재 타임존)
- `start < todayStart < end` 세션을 대상으로 전날/오늘 기여를 분할 계산
- 카드에 `전날 면적/시간`, `오늘 면적/시간`을 동시에 표시

## 6. 검증 포인트
- 23:50~00:20 세션에서 전날/오늘 비율이 시간 비례로 분배되는지 확인
- 주간 경계(일요일 23:50~월요일 00:20)에서 중복/누락 없이 합산되는지 확인
- 타임존 변경 notification 이후 홈 통계가 재계산되는지 확인
