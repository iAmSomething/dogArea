# Watch Smart Stack Glance Plan v1

- 대상 이슈: #525
- 관련 이슈: #511, #512, #518, #521, #522, #523, #524
- 목적: watchOS에서 앱을 열기 전 손목 위 glance 경험을 강화하기 위해, Smart Stack 및 complication 유사 표면의 우선 지원안과 상태별 정보 구조를 고정한다.

## 1. 범위와 전제

1. 이번 문서는 watchOS용 `Smart Stack glance surface`의 제품 계약이다.
2. 1차 우선 지원안은 `Smart Stack widget`이며, complication 유사 축약 표면은 같은 상태 모델을 공유하는 파생 family로 본다.
3. watch app 본문은 계속 primary interaction surface다. glance surface는 `확인 + 빠른 진입`까지만 담당한다.
4. 고빈도 실시간 스트리밍은 금지한다. 기존 watch 앱/Live Activity/폰 런타임보다 더 촘촘한 refresh를 요구하지 않는다.
5. backend contract를 새로 만들지 않는다. 기존 widget/watch snapshot과 route를 재사용한다.

## 2. 우선 지원안 결정

### 결정

- Phase 1 우선 지원 표면은 `Smart Stack widget`이다.
- complication 유사 표면은 `accessoryRectangular`를 canonical density로 삼고, `accessoryCircular`/`accessoryInline`는 축약 파생으로 정의한다.

### 이유

1. Smart Stack은 watch app 진입 전 glance 가치가 가장 높다.
2. `accessoryRectangular`는 active walk / inactive context를 모두 담을 수 있는 최소 밀도다.
3. `accessoryCircular`/`accessoryInline`만 먼저 가면 quest, selected pet, sync state를 함께 설명하기 어렵다.
4. watch app 본문이 이미 액션 밀도가 높으므로, glance 표면은 진입 전 상태 판단과 탭 유도에 집중해야 한다.

## 3. Surface 역할 분리

| surface | 역할 | 하지 않는 일 |
| --- | --- | --- |
| `Smart Stack widget` | 지금 무엇을 먼저 봐야 하는지 보여주고 적절한 화면으로 보낸다. | 다단계 조작, 상세 설정, queue 상세 대체 |
| `accessoryRectangular` | 핵심 지표 2~3개 + 상태 1개를 짧게 보여준다. | 긴 설명, 실패 사유 전체 노출 |
| `accessoryCircular` | 핵심 수치 또는 상태 1개만 보여준다. | selected pet + quest + sync 동시 노출 |
| watch app 본문 | 시작/종료/동기화/queue/반려견 문맥 확인 등 실제 액션을 담당한다. | glance 역할 대체 |

## 4. Active Walk 정보 우선순위

active walk 상태에서는 아래 우선순위를 고정한다.

1. `산책 타이머`
2. `현재 포인트 수`
3. `selected pet`
4. `sync 상태`는 degraded일 때만 승격

### Family별 규칙

| family | 기본 노출 | degraded sync일 때 |
| --- | --- | --- |
| `Smart Stack widget` | 타이머 + 포인트 수 + 반려견 이름 | 타이머 유지, 보조 줄을 `동기화 지연`으로 교체 |
| `accessoryRectangular` | `산책 n분` + `포인트 n개` + 반려견 | `포인트` 자리를 `동기화 지연`으로 치환 가능 |
| `accessoryCircular` | 타이머 또는 포인트 중 1개 | 심각 지연이면 경고 glyph 우선 |
| `accessoryInline` | `산책 18분` | `산책 18분 · 지연` |

### Active Walk 보조 규칙

1. selected pet은 active walk에서 항상 현재 세션 반려견 기준이다.
2. sync 상태는 `정상`일 때는 숨기고, `지연/대기/복구 필요`일 때만 보여준다.
3. 영역 수치가 있다면 Phase 1에서는 포인트 뒤의 secondary 데이터로만 취급한다. 타이머보다 앞서지 않는다.

## 5. Inactive 정보 우선순위

inactive 상태에서는 아래 우선순위를 고정한다.

1. `오늘 퀘스트 진행`
2. `selected pet readiness`
3. `territory next goal`
4. `마지막 sync 상태`는 stale일 때만 승격

### Family별 규칙

| family | 기본 노출 | stale/degraded일 때 |
| --- | --- | --- |
| `Smart Stack widget` | 오늘 퀘스트 진행 + 선택 반려견 + 다음 목표 요약 | 보조 줄을 `동기화 지연` 또는 `앱에서 확인`으로 치환 |
| `accessoryRectangular` | `퀘스트 3/5` + 반려견 이름 + 다음 목표/남은 면적 중 하나 | territory 보조 정보를 `마지막 동기화 지연`으로 교체 |
| `accessoryCircular` | 퀘스트 진행률 또는 준비 상태 glyph | 심각 지연이면 sync 경고 glyph 우선 |
| `accessoryInline` | `퀘스트 3/5` 또는 `산책 준비` | `퀘스트 3/5 · 지연` |

### Inactive 보조 규칙

1. 반려견이 비활성/미선택이면 `앱에서 반려견 확인`이 selected pet 대신 올라간다.
2. territory는 next goal 문맥만 노출한다. 홈 요약 카드 전체를 복제하지 않는다.
3. last sync는 `stale`일 때만 직접 보여준다. 정상일 때는 퀘스트/반려견 정보를 우선한다.

## 6. 후보 정보별 승격 규칙

| 정보 | active walk | inactive | 비고 |
| --- | --- | --- | --- |
| 산책 타이머 | 항상 1순위 | 노출하지 않음 | active 전용 |
| 포인트 수 | 2순위 | 노출하지 않음 | active 전용 |
| selected pet | 3순위 | 2순위 | inactive에서는 readiness 의미가 더 큼 |
| 오늘 퀘스트 진행 | 숨김 | 1순위 | inactive의 메인 glance |
| territory next goal | secondary | 3순위 | 홈 목표 상세와 역할 중복 금지 |
| 마지막 sync 상태 | degraded일 때만 승격 | stale/degraded일 때만 승격 | 정상 상태 상시 노출 금지 |

## 7. Refresh / Battery 정책

1. 기본 정책은 `event-driven + coarse cadence`다.
2. active walk여도 Smart Stack은 초단위 갱신을 요구하지 않는다.
3. 권장 cadence:
   - active walk: `1~5분` 수준 또는 canonical state change 시 갱신
   - inactive: 앱 재진입, sync 완료, quest/territory snapshot 변경 시 갱신
4. `sync delayed`, `queued`, `recovered` 같은 상태 전이는 event 우선으로 반영한다.
5. watch app 본문이 foreground일 때만 더 자세한 상태를 보여주고, glance surface는 최근 snapshot을 소비한다.

## 8. watch app 본문과의 역할 경계

glance surface는 아래를 하지 않는다.

1. queue 상세 목록 대체
2. `startWalk` / `endWalk` 다단계 확인 대체
3. 반려견 선택 변경
4. recovery 설명 전체 대체

glance surface는 아래를 한다.

1. 지금 watch app을 열 이유가 있는지 알려준다.
2. 어떤 탭/화면으로 들어갈지 예고한다.
3. sync 문제가 있으면 `지연`, `복구 필요`, `앱에서 확인` 수준으로만 요약한다.

## 9. 상태별 CTA/딥링크 규칙

| 상태 | 기본 탭 동작 | 보조 문구 |
| --- | --- | --- |
| active walk 정상 | 산책 화면/런타임 본문 | `산책 진행 중` |
| active walk sync delayed | watch app 런타임 본문 | `동기화 지연` |
| inactive + quest ready | 퀘스트/라이벌 보드 | `오늘 퀘스트 확인` |
| inactive + pet missing | iPhone 앱 defer 경유 후 반려견 확인 | `앱에서 반려견 확인` |
| territory next goal 강조 | 영역 목표 상세 | `다음 목표 보기` |
| recovery needed | watch app queue/recovery 문맥 | `다시 동기화 필요` |

## 10. Phase 1 레이아웃 제안

### Smart Stack widget

- active walk
  - headline: `산책 18분`
  - subline: `포인트 4개 · 민수`
  - degraded 시 subline: `동기화 지연 · 민수`
- inactive
  - headline: `오늘 퀘스트 3/5`
  - subline: `민수 · 다음 목표 0.10km²`
  - stale 시 subline: `동기화 지연 · 앱에서 확인`

### accessoryRectangular

- active: `산책 18분 / 포인트 4개 / 민수`
- inactive: `퀘스트 3/5 / 민수 / 다음 목표`

### accessoryCircular

- active: 타이머 또는 포인트
- inactive: 퀘스트 진행률 또는 준비 glyph

## 11. QA 체크포인트

1. Smart Stack 표면이 watch app 본문과 동일 정보 구조를 복제하지 않아야 한다.
2. active walk에서는 타이머가 항상 가장 먼저 보여야 한다.
3. inactive에서는 퀘스트 진행이 territory보다 앞서야 한다.
4. selected pet이 없을 때는 수치 대신 `앱에서 반려견 확인` 문맥이 보여야 한다.
5. 정상 sync 상태를 굳이 상시 노출하지 않아야 한다.
6. degraded/stale일 때만 sync 상태가 승격되어야 한다.
7. Smart Stack / accessoryRectangular / accessoryCircular의 정보 밀도 차이가 유지되어야 한다.
8. [Widget Lock Screen Accessory Family Plan v1](widget-lock-screen-accessory-family-plan-v1.md)와 충돌하지 않아야 한다.
