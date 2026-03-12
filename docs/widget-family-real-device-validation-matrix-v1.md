# Widget Family Real-Device Validation Matrix v1

- Issue: #751
- Relates to: #692, #731, #408

## 목적
- 홈 화면 위젯 4종의 `systemSmall`, `systemMedium` family를 실기기 기준으로 전수 조사한다.
- preview 기준이 아니라 실제 홈 화면 렌더링 기준으로 `clipping 0건`을 증적으로 남긴다.
- `#692`, `#731` 종료에 필요한 family별 layout budget 검증 축을 고정한다.

## 선행 문서
- 공통 family budget: `docs/home-widget-family-layout-budget-v1.md`
- action 수렴 검증: `docs/widget-action-real-device-validation-matrix-v1.md`
- 실기기 layout 런북: `docs/widget-family-real-device-evidence-runbook-v1.md`
- 복붙용 템플릿: `docs/widget-family-real-device-evidence-template-v1.md`
- 종료 체크리스트: `docs/widget-action-closure-checklist-v1.md`

## 조사 축
- Surface
  - `WalkControlWidget`
  - `TerritoryStatusWidget`
  - `QuestRivalStatusWidget`
  - `HotspotStatusWidget`
- Family
  - `systemSmall`
  - `systemMedium`
- 확인 항목
  - 상단 잘림
  - 하단 잘림
  - CTA 프레임 침범
  - 텍스트 수직 오버플로
  - metric tile 높이 불균형
  - badge / CTA 충돌
  - compact format fallback 동작

## 최소 실기기 검증 세트

| Case ID | Surface | Family | Covered States | Expected Result |
| --- | --- | --- | --- | --- |
| `WL-001` | `WalkControlWidget` | `systemSmall` | `idle`, `pending`, `failed`, `requiresAppOpen` | CTA와 상태 문구가 위젯 경계 안에서 수렴한다. |
| `WL-002` | `WalkControlWidget` | `systemMedium` | `walking`, `ended`, `succeeded` | 진행 상태/종료 상태가 CTA와 metric strip을 밀어내지 않는다. |
| `WL-003` | `TerritoryStatusWidget` | `systemSmall` | `guestLocked`, `emptyData` | headline/detail/badge가 2단 정보 구조 안에서 잘리지 않는다. |
| `WL-004` | `TerritoryStatusWidget` | `systemMedium` | `memberReady`, `offlineCached`, `syncDelayed` | 다음 목표/현재 목표/보조 문구가 compact fallback으로 수렴한다. |
| `WL-005` | `QuestRivalStatusWidget` | `systemSmall` | `guestLocked`, `claimFailed` | headline과 CTA가 겹치지 않고 실패 문구가 의미를 유지한다. |
| `WL-006` | `QuestRivalStatusWidget` | `systemMedium` | `memberReady`, `claimInFlight`, `claimSucceeded` | 보상/라이벌 문맥이 metric tile과 충돌하지 않는다. |
| `WL-007` | `HotspotStatusWidget` | `systemSmall` | `guestLocked`, `privacyGuarded` | privacy 가드 문구와 CTA가 프레임 밖으로 나가지 않는다. |
| `WL-008` | `HotspotStatusWidget` | `systemMedium` | `memberReady`, `offlineCached`, `syncDelayed` | 반경/상태/보조 문구가 family budget 안에서 수렴한다. |

## 기록 템플릿

| Date | Device / OS | Surface | Family | Covered States | Headline Policy | CTA Rule | Compact Rule | Actual | Pass/Fail |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | iPhone 16 Pro / iOS 18.x | `WalkControlWidget` | `systemSmall` | `idle`, `pending` | 2 lines max | 44-52pt | compact label fallback | 실제 결과 기입 | PASS / FAIL |

## 완료 규칙
- `WL-001` ... `WL-008`이 모두 채워져야 `#692`, `#731` 실기기 layout 증적이 충족된다.
- `Pass`가 아닌 케이스가 하나라도 있으면 blocker를 닫지 않는다.
- action 수렴 케이스 `WD-001` ... `WD-008`과 layout 케이스 `WL-001` ... `WL-008`을 함께 봐야 `#408` 종료 판단이 가능하다.
