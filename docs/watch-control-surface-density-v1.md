# Watch Control Surface Density v1

## 연결 이슈
- `#737`
- `#738`
- `#724`
- `#533`

## 문제 정의

watch control page는 `조작 전용 화면`처럼 읽혀야 한다. 다음이 동시에 떠 있으면 실패로 본다.

- 별도 카드처럼 보이는 상태 요약
- control page 안으로 다시 돌아온 feedback banner
- 별도 dock처럼 보이는 action block
- 별도 카드처럼 보이는 mini metric tile

작은 watch 높이에서 이 세 레이어가 경쟁하면 사용자는 control page를 독립 화면이 아니라 overlay처럼 인식한다.

## 결정

1. control page는 `WatchControlSurfaceView` 하나의 주된 surface만 사용한다.
2. `WatchMainStatusSummaryView`와 `WatchPrimaryActionDockView`만 control surface 내부 섹션으로 남긴다.
3. `WatchPrimaryActionDockView`는 overlay dock가 아니라 action section으로 동작한다.
4. `WatchActionBannerView`는 info page의 보조 정보 카드로 노출한다.
5. idle 상태도 control page에는 반려견 문맥을 다시 올리지 않는다.
6. walking 상태는 `elapsed / point / reachability + addPoint/end`만 남기고 secondary information을 올리지 않는다.
7. control page는 `ScrollView` 안에 있어 작은 높이에서도 전체 조작 surface에 접근할 수 있어야 한다.
8. information surface는 반려견 문맥, action feedback, 큐/동기화 상태를 담당한다.
9. 메트릭은 개별 card 여러 개가 아니라 `single metrics strip` 하나로 읽혀야 한다.
10. control page header는 `조작 화면`과 현재 상태를 먼저 보여 주고, page 목적을 즉시 설명해야 한다.
11. action section은 같은 surface 안의 마지막 섹션으로 읽혀야 하며, 별도 dock처럼 보이면 실패다.

## surface 우선순위

### idle
- headline
- 최소 메트릭 3개
- 시작 관련 feedback
- `산책 시작`

### walking
- headline
- 최소 메트릭 3개
- `영역 표시하기`
- `산책 종료`

## 금지

- `safeAreaInset(edge: .bottom)`로 조작 surface를 다시 overlay처럼 고정
- 상단 상태 카드와 하단 CTA 카드에 서로 다른 배경을 남겨 다층 surface처럼 보이게 만드는 구성
- 메트릭을 작은 background tile 여러 개로 나눠 또 다른 카드 층을 만드는 구성
- action feedback banner를 control page로 복귀시키는 구성
- info surface에 있는 queue/pet context를 control page로 다시 복귀시키는 구성

## 검증

- watch simulator build 성공
- `ios_pr_check` 통과
- 정적 체크에서 다음을 보장
  - `WatchControlSurfaceView`
  - `WatchSurfacePagingHintView`
  - control/info 양쪽 `ScrollView`
  - `safeAreaInset(edge: .bottom)` 제거
  - control page에서 banner 제거
  - info page의 feedback banner
  - single metrics strip
