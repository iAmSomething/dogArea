# Walk Live Activity Priority v1

## Scope
- Issue: `#519`
- Surface: `WalkLiveActivityWidget`
- Goal: 산책 중 Live Activity가 "지금 무엇이 쌓이고 있는지"를 시간/영역/안전 상태 순서로 더 명확하게 보여준다.

## Priority Rules
1. `expanded`는 `경과 시간`, `현재 확보 영역`, `자동 종료/복구 안전 상태`를 먼저 보여준다.
2. `포인트 수`는 현재 기록 밀도를 설명하는 보조 정보로 노출한다.
3. 액션 버튼(`종료`, `앱 열기`)은 정보 블록 하단에 고정해 메트릭 영역과 충돌하지 않게 한다.
4. 퀘스트/마일스톤은 이번 이슈에서 별도 서버/앱 상태를 추가하지 않고, 현재 산책 가치(`영역 증가량`)가 우선이다.

## Expanded Layout
- 헤더
  - 반려견 이름
  - 안전 상태 배지
- 메트릭 타일
  - `경과 시간`
  - `현재 확보 영역`
- 보조 정보
  - `포인트 수`
  - 안전 상태 상세 문구
- 액션
  - `종료`
  - `앱 열기`

## Dynamic Island
### Expanded
- `leading`: 경과 시간
- `trailing`: 현재 확보 영역
- `center`: 반려견 이름 + 포인트 수
- `bottom`: 자동 종료/복구 안전 상태

### Compact
- `leading`: 축약 경과 시간
- `trailing`
  - 기본: 축약 영역 증가량
  - 예외: `warning`, `autoEnding`, `ended` 상태는 안전 상태 짧은 라벨 우선

### Minimal
- 상태 심볼만 유지
  - `active`: `figure.walk`
  - `restCandidate`: `pause.circle`
  - `warning`: `exclamationmark.triangle.fill`
  - `autoEnding`: `stop.circle.fill`
  - `ended`: `checkmark.circle.fill`

## Low Power / Reduce Motion
- 이번 변경은 Live Activity 동기화 주기를 추가로 높이지 않는다.
- 기존 `liveActivitySyncInterval`과 상태 변화 기반 강제 동기화만 유지한다.
- 애니메이션이나 연속 숫자 효과를 추가하지 않고 정적 텍스트/배지/타일만 사용한다.

## Data Contract
- `WalkLiveActivityState`
  - `capturedAreaM2`
- `WalkLiveActivityAttributes.ContentState`
  - `capturedAreaM2`

## Done Criteria Mapping
- `expanded/compact/minimal` 우선순위가 각각 문서로 정의되어 있다.
- compact/minimal은 과밀하지 않게 `시간` 또는 `영역/안전 상태` 하나만 유지한다.
- 자동 종료 경고 문맥이 영역/시간 정보보다 사라지지 않는다.
