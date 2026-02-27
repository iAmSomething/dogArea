# Map Banner Priority Queue v1 (Issue #137)

## 1. 목표
- Map 상단 상태 배너를 우선순위 큐로 통합해, 동일 시점에 **최대 1개 배너**만 노출한다.
- 치명도 높은 상태(P0)가 항상 먼저 노출되도록 보장한다.

## 2. 우선순위 정의
- `P0`
  - 복구 액션 배너(`RecoveryActionBanner`: 권한 거부/인증 만료/오프라인 복구)
  - 미종료 산책 세션 배너
- `P1`
  - 동기화 상태 배너(`syncOutbox`)
  - 런타임 가드 배너(`runtimeGuard`)
  - 오프라인 모드 배지
- `P2`
  - 게스트 백업 CTA 배너
  - 워치 상태 배너

## 3. 노출 규칙
- 후보 배너 목록을 생성한 뒤 `severity asc`로 정렬하고 첫 번째 항목만 활성 배너로 채택.
- 각 배너는 `suppressFor`를 가져 dismiss 후 재노출까지 최소 간격을 가진다.
- `P1/P2` 일부 배너는 `autoDismissAfter`를 사용해 자동으로 내려간다.
- 활성 배너 변경 시 이전 auto-dismiss task는 즉시 취소 후 재스케줄한다.

## 4. UX 정책
- 복구성(P0) 배너는 자동 dismiss 하지 않는다.
- 정보성(P1/P2) 배너는 짧게 노출 후 자동 dismiss 하여 지도 조작 가림을 줄인다.
- 배너 렌더 경로는 `topBannerView(for:)` 단일 함수로 통합한다.

## 5. 회귀 체크 포인트
- 동시 배너 겹침(2개 이상) 0건
- 동일 시점에 P0/P1 공존 시 P0가 먼저 노출
- dismiss/auto-dismiss 후 suppression 윈도우 동안 즉시 재노출되지 않음
