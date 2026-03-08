# Watch Selected Pet Context UX v1

## Scope
- Issue: #521
- Related: #513, #520

## Product Decision
- Apple Watch는 `현재 선택 반려견`을 **읽기 전용**으로 보여준다.
- 반려견 변경의 canonical source는 계속 iPhone 앱이다.
- watch는 선택 반려견을 바꾸지 않고, `현재 어떤 반려견으로 산책이 시작될지`를 명확하게 보여주고 필요하면 다시 동기화한다.

## Why Read-Only
- 다중 반려견 선택 정책은 이미 iPhone 앱이 소유하고 있다.
- watch에서 별도 선택 정책을 만들면 iPhone 선택 상태와 쉽게 어긋난다.
- v1에서는 watch의 역할을 `확인`과 `액션 트리거`로 제한하고, 선택 변경은 iPhone으로 유지한다.

## Canonical Context Source
- iPhone 앱은 `WalkWidgetPetContext` 규칙을 그대로 재사용해서 watch application context를 만든다.
- watch payload에는 아래 정보가 포함된다.
  - `pet_id`
  - `pet_name`
  - `badge_title`
  - `detail`
  - `source`
  - `is_read_only`
  - `blocks_inline_start`

## Source States
- `selected_pet`
  - 현재 선택 반려견이 유효하다.
  - badge: `선택 반려견`
- `fallback_active_pet`
  - 저장된 선택 반려견이 비활성/삭제되어 활성 반려견으로 대체했다.
  - badge: `자동 대체`
- `walking_locked`
  - 산책 시작 시점에 확정된 반려견을 세션 종료까지 유지한다.
  - badge: `산책 고정`
- `no_active_pet`
  - 활성 반려견이 없어 watch inline start를 막는다.
  - badge: `앱 확인`

## Divergence Fallback
- watch가 보여주는 반려견과 iPhone 선택 상태가 다를 수 있는 대표 시나리오:
  1. iPhone에서 반려견을 변경했지만 watch가 아직 재동기화되지 않음
  2. 저장된 선택 반려견이 비활성/삭제됨
  3. 현재 활성 반려견이 없음
- fallback 규칙:
  - watch는 `반려견 다시 확인` 액션으로 `syncState`를 보낸다.
  - iPhone은 최신 선택 상태를 다시 계산해 watch에 재발행한다.
  - `fallback_active_pet`이면 watch에 fallback 설명을 노출한다.
  - `no_active_pet`이면 watch 시작을 막고 `앱에서 먼저 확인` 문맥을 노출한다.

## Start Action Contract
- watch `startWalk` 액션은 현재 화면에 노출 중인 `pet_id`를 `context_id`로 함께 전송한다.
- iPhone은 start 처리 직전에 `context_id`가 여전히 활성 반려견인지 확인한다.
- 유효하면 그 반려견을 선택 상태에 반영하고 산책을 시작한다.
- 유효하지 않으면 현재 활성 반려견으로 fallback 후 시작하거나, 활성 반려견이 없으면 요청을 reject 한다.

## Walking Lock Rule
- 산책 중에는 iPhone에서 선택 반려견이 바뀌어도 watch는 현재 세션 반려견을 계속 보여준다.
- 즉 `selected pet`과 `walking pet`을 분리하되, watch 산책 표면은 항상 `walking_locked` 문맥을 우선한다.

## Watch Surface Rules
- action 버튼 위에 반려견 문맥 카드가 항상 노출된다.
- 카드에는 다음 요소가 들어간다.
  - badge
  - 반려견 이름
  - 한 줄 설명
  - `반려견 변경은 iPhone 앱에서`라는 read-only note
- `fallback_active_pet`, `no_active_pet`, `오프라인`일 때는 `반려견 다시 확인` 버튼을 노출한다.

## Guardrails
- `blocks_inline_start == true`이면 watch `산책 시작` 버튼은 비활성화한다.
- watch가 잘못된 상태로 start를 보내더라도 iPhone은 최종 검증 후 reject 할 수 있다.
- reject ACK에는 실패 이유 문구를 포함해 watch가 그대로 사용자에게 보여준다.

## QA Checklist
- watch 첫 화면에서 현재 반려견 이름이 보인다.
- 선택 반려견이 비활성/삭제되면 `자동 대체` badge가 보인다.
- 활성 반려견이 없으면 `산책 시작`이 비활성화된다.
- watch start action payload에 `context_id`가 포함된다.
- 산책 시작 후 iPhone에서 선택 반려견을 바꿔도 watch는 `산책 고정` 문맥을 유지한다.
- iPhone과 watch 문맥이 달라 보일 때 `반려견 다시 확인`으로 최신 상태를 다시 받는다.
