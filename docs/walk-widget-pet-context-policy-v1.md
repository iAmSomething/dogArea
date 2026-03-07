# Walk Widget Pet Context Policy v1

## Scope
- Issue: #513
- Related: #512, #511

## Current Product Decision
- WalkControl 위젯의 산책 시작은 `현재 선택 반려견` 문맥을 사용한다.
- 위젯별 `특정 반려견 고정 구성`은 아직 제공하지 않는다.
- 다만 위젯 액션 라우트의 `contextId`는 future fixed-pet rollout을 위해 예약한다.

## Start Policy

### Canonical Policy
- `selected_pet_immediate`
  - 현재 선택 반려견으로 즉시 시작한다.
- `selected_pet_countdown`
  - 현재 선택 반려견으로 카운트다운 시작한다.
- `fixed_pet_reserved`
  - 향후 위젯별 고정 반려견 구성을 위한 예약 값이다.

## Pet Context Resolution

### Idle
1. `userInfo.selectedPetId`가 활성 반려견과 일치하면 그 반려견을 사용한다.
2. 저장된 선택 반려견이 비활성/삭제되었으면 첫 번째 활성 반려견으로 fallback 한다.
3. 활성 반려견이 없으면 inline start를 막고 앱 확인 CTA를 노출한다.

### Walking
- 산책 중에는 `산책 시작 시 확정된 반려견 문맥`을 유지한다.
- 이후 앱 내부에서 선택 반려견이 바뀌더라도 위젯의 active walk 표면은 현재 세션 반려견을 계속 표시한다.

## Widget Surface Rules
- 반려견 이름은 항상 위젯에 표시한다.
- 이름 아래에는 문맥 설명 한 줄을 표시한다.
- 상태 badge는 다음 중 하나를 사용한다.
  - `선택 반려견`
  - `자동 대체`
  - `산책 고정`
  - `앱 확인`
- 활성 반려견이 없으면 `산책 시작` 대신 `앱에서 반려견 확인` CTA를 사용한다.

## Action Routing Rules
- `StartWalkIntent`는 현재 위젯 snapshot의 `petContext.petId`를 `contextId`로 앱에 넘긴다.
- 앱은 start action 처리 직전 `contextId`가 여전히 활성 반려견인지 검증한다.
- 유효하면 그 반려견을 선택 상태에 적용한 뒤 산책을 시작한다.
- 유효하지 않으면 현재 활성 반려견으로 fallback 하거나, 활성 반려견이 없으면 앱 확인 상태로 전환한다.

## Fallback Copy
- 선택 반려견이 사라진 경우: `선택 반려견을 찾지 못해 활성 반려견으로 조정했어요.`
- 활성 반려견이 전혀 없는 경우: `활성 반려견이 없어 앱에서 먼저 확인이 필요해요.`
- 산책 중 잠금 상태: `산책 시작 시 확정된 반려견을 유지해요.`

## Compatibility
- 기존 저장 snapshot에 `petContext`가 없어도 `petName + isWalking` 기반 legacy fallback으로 복원한다.
- v1에서는 current selection 정책만 활성화하고, `fixed_pet_reserved`는 문서/모델 예약만 한다.

## QA Checklist
- 선택 반려견 이름이 위젯에 노출된다.
- 카운트다운 설정 on/off에 따라 설명 문구가 바뀐다.
- 저장된 선택 반려견이 비활성/삭제되면 `자동 대체` badge가 노출된다.
- 활성 반려견이 없으면 start CTA 대신 앱 확인 CTA가 노출된다.
- 산책 시작 후 앱에서 선택 반려견이 바뀌어도 위젯은 시작한 반려견을 유지한다.
