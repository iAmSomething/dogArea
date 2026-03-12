# Watch 메인 화면 overflow scroll UX v1

## 목표

- watch 메인 화면에서 정보 카드가 길어져도 모든 텍스트와 CTA에 접근 가능해야 한다.
- 핵심 CTA인 `산책 시작`, `영역 표시하기`, `산책 종료`는 작은 화면에서도 항상 접근 가능해야 한다.
- 터치 스크롤과 Digital Crown 스크롤이 모두 가능한 구조를 유지한다.
- `조작 화면`과 `정보 화면`의 목적이 서로 섞이지 않아야 한다.

## 연결 이슈
- `#533`
- `#698`
- `#724`
- `#737`
- `#738`

## 결정

1. 메인 화면을 `control surface`와 `information surface` 두 페이지로 분리한다.
2. 기본 landing은 항상 `control surface`다.
3. `control surface`와 `information surface` 모두 `ScrollView`를 사용해 overflow를 허용한다.
4. `control surface`는 `WatchControlSurfaceView` 하나의 주된 surface 안에 상태 요약과 CTA만 통합한다.
5. `WatchPrimaryActionDockView`는 더 이상 `safeAreaInset(edge: .bottom)` overlay로 고정하지 않고 control surface 내부 섹션으로 배치한다.
6. 반려견 문맥/최근 action feedback/오프라인 큐/상세 recovery 정보는 `information surface`에서 읽고, control surface에는 최소 상태와 조작만 남긴다.
7. CTA 버튼은 `minHeight 52pt` 이상을 유지하고, 제목/설명은 multiline 허용으로 Dynamic Type 증가에 대응한다.
8. 큐 상태 카드의 chip/action row는 `ViewThatFits`로 horizontal 우선, 실패 시 vertical fallback 한다.
9. 최초 진입 시에는 `WatchSurfacePagingHintView`로 다른 page 존재를 알려 주되, 정보 페이지를 한 번 방문하면 hint를 내린다.
10. control surface 메트릭은 작은 카드 여러 개가 아니라 하나의 strip 안에서 읽히게 정리한다.
11. information surface는 첫 줄부터 `정보 화면` heading을 보여 control page와 목적을 구분한다.

## 우선순위

### control surface
- 단일 card surface 안에서 현재 산책 상태와 최소 메트릭
- 메트릭은 `single metrics strip` 하나로 묶고 작은 타일 카드 여러 개로 분리하지 않는다.
- 같은 surface 안에서 핵심 CTA를 바로 이어서 노출

### information surface
- 상단: 반려견 문맥
- 중단 상단: 최근 action feedback
- heading: `정보 화면`
- 중단: 큐/동기화 상태
- 하단: 필요 시 페이지 이동 affordance
- feedback banner는 control surface에 중복 노출하지 않는다.

## 비범위

- WatchConnectivity contract 변경
- iPhone식 다단 대시보드 유지
- 패딩만 조정해 overlay 느낌을 남기는 방식

## 검증

- watch 빌드 성공
- `ios_pr_check` 통과
- 정적 체크에서 `TabView + control/info split + control/info scroll + integrated control surface + multiline/minHeight`를 보장
