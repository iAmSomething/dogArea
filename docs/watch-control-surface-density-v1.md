# Watch Control Surface Density v1

## 연결 이슈
- `#737`
- `#738`
- `#724`
- `#533`

## 문제 정의

watch control page는 `조작 전용 화면`처럼 읽혀야 한다. 다음이 동시에 떠 있으면 실패로 본다.

- 별도 카드처럼 보이는 상태 요약
- 별도 카드처럼 보이는 feedback banner
- 별도 dock처럼 보이는 action block

작은 watch 높이에서 이 세 레이어가 경쟁하면 사용자는 control page를 독립 화면이 아니라 overlay처럼 인식한다.

## 결정

1. control page는 `WatchControlSurfaceView` 하나의 주된 surface만 사용한다.
2. `WatchMainStatusSummaryView`, `WatchActionBannerView`, `WatchPrimaryActionDockView`는 모두 그 surface 내부 섹션으로 들어간다.
3. `WatchPrimaryActionDockView`는 overlay dock가 아니라 action section으로 동작한다.
4. `WatchActionBannerView`는 control page에서 `.inline` 스타일을 사용한다.
5. idle 상태는 `반려견 문맥 + 시작 CTA`를 먼저 보여준다.
6. walking 상태는 `elapsed / point / reachability + addPoint/end`만 남기고 secondary information을 올리지 않는다.
7. control page는 `ScrollView` 안에 있어 작은 높이에서도 전체 조작 surface에 접근할 수 있어야 한다.
8. information surface는 반려견 문맥과 큐/동기화 상태를 담당하고, 동일 banner를 중복 노출하지 않는다.

## surface 우선순위

### idle
- headline
- 현재 반려견 문맥
- 시작 관련 feedback
- `산책 시작`

### walking
- headline
- 최소 메트릭 3개
- 액션 feedback
- `영역 표시하기`
- `산책 종료`

## 금지

- `safeAreaInset(edge: .bottom)`로 조작 surface를 다시 overlay처럼 고정
- 상단 상태 카드와 하단 CTA 카드에 서로 다른 배경을 남겨 다층 surface처럼 보이게 만드는 구성
- info surface에 있는 queue/pet context를 control page로 다시 복귀시키는 구성

## 검증

- watch simulator build 성공
- `ios_pr_check` 통과
- 정적 체크에서 다음을 보장
  - `WatchControlSurfaceView`
  - `WatchSurfacePagingHintView`
  - control/info 양쪽 `ScrollView`
  - `safeAreaInset(edge: .bottom)` 제거
  - control page의 inline banner
