# Area Goal Ascending Order v1

## 목적
- 비교군/다음 목표를 면적 오름차순으로 일관 표시해 목표 체감을 개선한다.

## 정책
1. 기준 정렬은 `area asc`.
2. `nextGoal`은 `currentArea`보다 큰 값 중 최소값.
3. `recentConquered`는 `currentArea`보다 작은 값 중 최대값.
4. DB/로컬 fallback/뷰모델 계산 로직 모두 같은 방향(오름차순)으로 유지.

## 영향 파일
- `dogArea/Views/HomeView/AreaMeters.swift`
- `dogArea/Views/HomeView/HomeViewModel.swift`

## 수용 기준
- 0 면적 근처에서 다음 목표가 저면적 비교군부터 안내된다.
- 홈 목표 카드/상세 카탈로그 순서가 서로 모순되지 않는다.
