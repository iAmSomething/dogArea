# Walk Widget Action Convergence v1

- 대상 이슈: #617
- 관련 이슈: #512, #513
- 목적: 위젯 `start/end` 액션 이후 위젯 스냅샷, Live Activity, 앱 세션 상태가 서로 어긋나지 않도록 정본과 수렴 규칙을 고정한다.

## 1. 정본 정의

1. 산책 진행 여부의 정본은 앱 세션(`MapViewModel.isWalking`)이다.
2. `WalkWidgetSnapshot.actionState`는 정본이 아니라 짧은 수명의 transient overlay다.
3. Live Activity는 위젯 overlay를 따르지 않고 앱 canonical 산책 상태만 따른다.

## 2. 액션 상태 수렴 규칙

1. `pending(startWalk)` 상태에서 앱 canonical 산책 상태가 `isWalking == true`가 되면 즉시 `succeeded(startWalk)`로 수렴한다.
2. `pending(endWalk)` 상태에서 앱 canonical 산책 상태가 `isWalking == false`가 되면 즉시 `succeeded(endWalk)`로 수렴한다.
3. `pending` TTL이 끝났는데 canonical 상태가 아직 맞지 않으면:
   - `ready`면 `requiresAppOpen`
   - `locationDenied / sessionConflict / error`면 `failed + openApp`
4. `requiresAppOpen` TTL이 끝났는데도 canonical 상태가 맞지 않으면 `failed + openApp`으로 내린다.
5. `succeeded` / `failed`는 각 TTL이 끝나면 제거한다.

## 3. 딥링크와 pending 요청 중복 소비 규칙

1. 위젯 intent는 App Group 저장소에 pending 요청을 저장할 수 있다.
2. 앱이 딥링크 URL을 직접 파싱한 경우, 동일 `actionId`의 pending 요청은 즉시 제거한다.
3. 이 제거 규칙이 없으면 `didBecomeActive` 경로에서 같은 액션이 한 번 더 소비될 수 있다.

## 4. 앱 활성화 시 재동기화 규칙

1. 앱 `onAppear` / `didBecomeActive` / 인증 오버레이 해제 시점에는 준비된 `MapViewModel`이 있으면 `reconcileWalkWidgetActionSurfacesOnAppActive()`를 호출한다.
2. 이 재동기화는 다음 두 표면을 함께 맞춘다.
   - `WalkWidgetSnapshot`
   - `WalkLiveActivity`
3. 지도 ViewModel이 아직 준비되지 않은 경우에는 강제로 생성하지 않는다.

## 5. 관측성 규칙

1. pending 요청을 딥링크 경로에서 제거하면 `widget_action_pending_discarded`
2. pending/앱확인 상태가 canonical 세션 기준으로 성공 수렴하면 `widget_action_converged`
3. pending/앱확인 상태가 더 강한 후속 행동으로 올라가면 `widget_action_escalated`

## 6. QA 체크포인트

1. 위젯 `startWalk` 후 앱이 이미 산책 중 상태가 되면 widget overlay가 `succeeded`로 수렴하는지 확인
2. 위젯 `endWalk` 후 앱 canonical 상태가 종료로 바뀌면 Live Activity도 함께 종료되는지 확인
3. 딥링크로 앱이 열린 뒤 `didBecomeActive`에서 같은 actionId가 재소비되지 않는지 확인
4. 위치 권한 거부/세션 충돌 시 pending 만료 후 `failed + openApp`으로 올바르게 상승하는지 확인
5. 인증 오버레이가 열린 상태에서 요청이 들어오면 overlay 해제 후 재처리되고, 그 사이 위젯은 `requiresAppOpen`으로 보이는지 확인
