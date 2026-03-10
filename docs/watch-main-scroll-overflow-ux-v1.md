# Watch 메인 화면 overflow scroll UX v1

## 목표

- watch 메인 화면에서 정보 카드가 길어져도 모든 텍스트와 CTA에 접근 가능해야 한다.
- 핵심 CTA인 `산책 시작`, `영역 표시하기`, `산책 종료`는 작은 화면에서도 항상 접근 가능해야 한다.
- 터치 스크롤과 Digital Crown 스크롤이 모두 가능한 구조를 유지한다.
- `조작 화면`과 `정보 화면`의 목적이 서로 섞이지 않아야 한다.

## 연결 이슈
- `#533`
- `#698`

## 결정

1. 메인 화면을 `control surface`와 `information surface` 두 페이지로 분리한다.
2. 기본 landing은 항상 `control surface`다.
3. `information surface`만 `ScrollView`를 사용한다.
4. `WatchPrimaryActionDockView`는 `control surface`에서만 `safeAreaInset(edge: .bottom)`로 붙는다.
5. 반려견 문맥/오프라인 큐/보조 배너는 `information surface`에서 읽는다.
6. CTA 버튼은 `minHeight 52pt` 이상을 유지하고, 제목/설명은 multiline 허용으로 Dynamic Type 증가에 대응한다.
7. 큐 상태 카드의 chip/action row는 `ViewThatFits`로 horizontal 우선, 실패 시 vertical fallback 한다.

## 우선순위

### control surface
- 상단: 현재 산책 상태와 최소 메트릭
- 중단: 최근 액션 배너 1개
- 하단 고정: 핵심 CTA

### information surface
- 상단: 최근 액션 배너 1개
- 중단: 반려견 문맥
- 하단: 큐/동기화 상태

## 비범위

- WatchConnectivity contract 변경
- iPhone식 다단 대시보드 유지
- 패딩만 조정해 overlay 느낌을 남기는 방식

## 검증

- watch 빌드 성공
- `ios_pr_check` 통과
- 정적 체크에서 `TabView + control/info split + info scroll + control-only dock + multiline/minHeight`를 보장
