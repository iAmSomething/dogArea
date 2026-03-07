# Walk Widget Action State Model v1

- 대상 이슈: #512
- 관련 이슈: #408, #511
- 목적: `WalkControlWidget`의 시작/종료 액션이 `대기/처리중/성공/실패/앱 열기 필요` 단계로 어떻게 표현되는지 고정한다.

## 1. 문제 정의

1. 기존 산책 위젯은 `statusMessage` 한 줄에 액션 진행과 일반 산책 상태를 함께 실었다.
2. 이 구조에서는 `처리 중`, `실패`, `앱에서 확인 필요`를 구분하기 어렵고, 중복 탭을 막는 기준도 불명확했다.
3. 앱 런타임이 일반 산책 스냅샷을 다시 저장하면 직전 액션 상태가 쉽게 덮여 사용자에게 어긋난 문구가 남을 수 있었다.

## 2. 모델 분리 원칙

1. 산책 자체 상태는 기존 `WalkWidgetSnapshot.status`가 계속 담당한다.
2. 위젯 액션 표현은 별도 `actionState`로 분리한다.
3. 위젯 UI는 `actionState`가 있으면 그 상태를 우선 노출하고, 없으면 기존 `statusMessage`를 사용한다.
4. `actionState`는 짧은 TTL을 가지며, 일반 스냅샷 동기화와 충돌하지 않게 자동 소거된다.

## 3. 상태 모델

### 3-1. Action phase

| phase | 의미 | 중복 탭 | 기본 후속 행동 |
| --- | --- | --- | --- |
| `pending` | 위젯 탭은 접수됐고 앱 라우팅을 시작하는 중 | 차단 | 없음 |
| `requiresAppOpen` | 최종 확인은 앱에서 이어져야 함 | 허용 | `앱에서 확인` |
| `succeeded` | 요청이 앱에서 반영됨 | 정상 버튼 복귀 | 없음 |
| `failed` | 요청이 반려됨 또는 완료되지 않음 | 허용 | `다시 시도` 또는 `앱에서 확인` |

### 3-2. Follow-up

| followUp | 의미 | UI 정책 |
| --- | --- | --- |
| `none` | 추가 행동 불필요 | 기본 시작/종료 버튼 복귀 |
| `retry` | 같은 액션을 한 번 더 시도 가능 | `다시 시도` 버튼 |
| `openApp` | 위젯만으로는 부족하고 앱 확인 필요 | `앱에서 확인` 버튼 |

## 4. 시작/종료 액션 전이

| 시점 | 상태 | 메시지 예시 | 버튼 상태 |
| --- | --- | --- | --- |
| 위젯 탭 직후 | `pending` | `산책 시작 요청을 보냈어요.` / `산책 종료 요청을 보냈어요.` | disabled |
| 인증 오버레이로 지연 | `requiresAppOpen` | `로그인 후 앱에서 계속 확인해 주세요.` | `앱에서 확인` |
| 시작 성공 | `succeeded` | `산책을 시작했어요.` | 기본 버튼 복귀 |
| 종료 성공 | `succeeded` | `산책을 종료했어요.` | 기본 버튼 복귀 |
| 이미 산책 중 | `failed + openApp` | `이미 산책 중이에요. 앱에서 현재 세션을 확인해 주세요.` | `앱에서 확인` |
| 종료할 산책 없음 | `failed + openApp` | `종료할 산책을 찾지 못했어요. 앱에서 현재 상태를 확인해 주세요.` | `앱에서 확인` |
| 위치 권한 없음 | `failed + openApp` | `위치 권한이 필요해요. 앱에서 권한을 확인해 주세요.` | `앱에서 확인` |

## 5. 스냅샷 충돌 방지 규칙

1. `WalkWidgetSnapshot.status`는 `ready/locationDenied/sessionConflict/error` 도메인 상태를 유지한다.
2. `actionState`는 별도 필드로 저장한다.
3. 일반 `syncWalkWidgetSnapshot(...)`는 명시적 override가 없으면 기존 `actionState`를 보존하되, TTL이 지난 경우 제거한다.
4. 위젯 스냅샷 저장 시 `elapsedSeconds` 변화만으로는 timeline reload를 강제하지 않는다.
5. `isWalking/status/statusMessage/actionState`가 실제로 바뀐 경우에만 `WalkControlWidget` timeline을 reload한다.

## 6. UI 규칙

1. `pending`에서는 상단 배지 `처리 중` + progress를 표시하고, 주 버튼은 disabled 상태로 바꾼다.
2. `requiresAppOpen`에서는 상단 배지 `앱 확인`, 주 버튼은 `앱에서 확인`으로 바꾼다.
3. `failed + retry`에서는 `다시 시도` 버튼을 노출한다.
4. `failed + openApp`에서는 `앱에서 확인` 버튼을 노출한다.
5. `succeeded`는 짧게 노출한 뒤 기본 시작/종료 버튼으로 복귀한다.

## 7. QA 체크포인트

1. 위젯 탭 직후 버튼이 즉시 disabled되어 중복 탭이 줄어드는지 확인
2. 앱 지연/인증 필요 상황에서 `앱에서 확인` 상태가 노출되는지 확인
3. 위치 권한 거부/세션 충돌 시 실패 문구가 다음 행동을 제안하는지 확인
4. 성공 후 기본 버튼으로 복귀할 때 메시지가 과도하게 남지 않는지 확인
5. 일반 산책 경과 시간 업데이트가 액션 배지 때문에 과도한 timeline reload를 만들지 않는지 확인
