# 지도 상단 overlay 우선순위 매트릭스 v1

## 목적

`MapView`는 이미 recovery / recoverable session / return-to-origin / sync / runtime / offline / watch 상태를 top banner priority로 다룹니다.  
여기에 `#465`의 quest feedback HUD와 `#467`의 HUD 정보셋을 실제로 얹으려면, **어떤 표면이 top overlay slot을 점유하고 어떤 표면이 toast slot으로 빠지는지**를 먼저 고정해야 합니다.

이 문서는 `#468`의 구현 기준입니다.

## 3계층 분류

이 문서의 canonical 분류는 `critical / operational / progress` 3계층입니다.

- `critical`
  - `recoveryIssue`
  - `recoverableSession`
  - `returnToOrigin`
- `operational`
  - `syncOutbox`
  - `runtimeGuard`
  - `offlineMode`
  - `watchStatus`
  - `guestBackup`
- `progress`
  - quest companion HUD
  - quest expanded checklist
  - quest milestone toast

## 슬롯 역할

### top overlay slot

- 지도 chrome 안에서 **동시에 하나의 banner 계층만** 점유합니다.
- quest HUD는 top overlay slot의 독립 banner가 아니라, banner가 비었을 때는 `primary progress surface`, operational banner가 있을 때만 `collapsed secondary row`로 공존합니다.
- 작은 화면 또는 season tile detail 패널이 열린 상태에서는 `single top slot`만 허용합니다.

### toast slot

- milestone toast는 top overlay slot과 분리된 비차단 피드백 전용입니다.
- toast는 화면 reflow를 일으키지 않습니다.
- critical banner 전환 중에는 보이지 않고 queue에 들어갑니다.

## 기본 결정

- critical banner는 항상 단독 노출
- operational banner는 quest HUD보다 top slot 우선권을 가짐
- quest HUD는 기본 persistent
- critical 등장 시 즉시 숨김
- operational 등장 시 `collapsed single line`로 축약
- 사용자가 HUD를 닫으면 `120초` suppress
- 단, 대표 미션 상태가 `completed` 또는 `claimable`로 상승하면 suppress를 즉시 해제 가능

## animation / transition guard

- top slot은 `1.5초` stable window 안에서는 잦은 교체를 피하고 coalesce
- non-critical 교체는 `0.35초` coalescing window로 묶음
- critical preemption만 즉시 교체 허용
- toast는 top slot이 안정화되기 전에는 `queued until top slot settles`

## 상태표

| 시나리오 | active tier | top overlay slot | quest HUD | toast slot | 비고 |
| --- | --- | --- | --- | --- | --- |
| 권한/복구/종료 제안 | critical | critical banner only | hidden by critical banner | queued | critical가 끝난 뒤 HUD 복귀 |
| sync/runtime/offline 배너 + regular 화면 | operational | operational banner + collapsed HUD | collapsed single line | queued | 배너가 내려가면 HUD 원래 상태 복귀 |
| watch/guest 배너 + compact 화면 | operational | operational banner only | hidden by density guard | queued | 작은 화면에서는 공존 금지 |
| quest만 활성 | progress | quest HUD only | expanded | visible | 대표 미션 1개 중심 |
| quest 다중 진행 | progress | quest HUD only | collapsed single line | visible | `대표 1개 + 추가 n개` 유지 |
| 사용자가 HUD 닫음 | 없음 또는 operational | none 또는 operational banner only | suppressed by user | visible | suppress duration 120초 |

## runtime 해석 규칙

1. `critical`이 있으면 quest HUD는 숨기고 toast도 queue로 돌립니다.
2. `operational`만 있으면:
   - regular density: banner + collapsed HUD 공존
   - compact density 또는 season detail expanded: banner only
3. `progress`만 있으면 HUD가 top overlay의 주 surface가 됩니다.
4. toast는 `critical`과 경쟁하지 않고, `operational`과도 동시에 튀지 않게 stable window 뒤로 밀립니다.

## 구현 메모

- top slot priority는 기존 `MapTopBannerKind` ordering과 별개로 `tier -> slot mode` 해석 단계를 한 번 더 둡니다.
- quest HUD의 `expanded / collapsed / suppressed / hiddenByCritical`는 banner queue와 분리된 상태로 유지해야 합니다.
- milestone toast는 `banner queue`에 넣지 말고 별도 lane으로 다룹니다.
- `#465`의 toast/haptic 정책과 `#467`의 collapsed 정보셋은 이 매트릭스 위에서만 실행합니다.

## QA 포인트

- critical banner가 떠 있을 때 quest HUD가 top chrome에서 완전히 사라지는지
- operational banner가 있을 때 HUD가 1줄 collapsed로만 남는지
- 작은 화면에서 banner + HUD 이중 노출이 발생하지 않는지
- milestone toast가 critical banner 전환 중에 겹쳐 뜨지 않는지
- 사용자가 HUD를 닫은 뒤 120초 내에 재등장하지 않는지
