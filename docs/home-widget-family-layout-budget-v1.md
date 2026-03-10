# Home Widget Family Layout Budget v1

Issue: #692
Related: #614, #615, #617

## Scope

대상 홈 화면 위젯 4종:
- `WalkControlWidget`
- `TerritoryStatusWidget`
- `QuestRivalStatusWidget`
- `HotspotStatusWidget`

지원 family:
- `systemSmall`
- `systemMedium`

## Shared family budget

공통 예산 정본은 `WidgetSurfaceLayoutBudget`입니다.

### systemSmall
- headline: `lineLimit(1)`
- detail / status: `lineLimit(1)`
- CTA: `minHeight 34`, `maxHeight 38`, `lineLimit(1)`
- badge: 최대 `2개`, 초과 시 `+N` 배지로 축약
- metric tile: `minHeight 48`, vertical padding `6`, horizontal padding `8`
- compact fallback
  - elapsed: `59m`, `2h`, `45s`
  - area: `42㎡`, `0.8만㎡`, `1.2k㎡`
  - percent: `NN%`

### systemMedium
- headline: `lineLimit(2)`
- detail / status: `lineLimit(2)`
- CTA: `minHeight 40`, `maxHeight 46`, `lineLimit(2)`
- badge: 최대 `2개`, 초과 시 `+N` 배지로 축약
- metric tile: `minHeight 58`, vertical padding `8`, horizontal padding `9`
- formatting fallback
  - elapsed: `HH:MM:SS`
  - area: 기본 `formattedArea`
  - percent: `NN%`

## Surface-specific policy

### WalkControlWidget
- small은 `badge -> 상태 제목 -> 반려견명 -> 경과시간 -> support 1줄 -> CTA`만 유지합니다.
- small은 `pet detail`과 `status message`를 분리해서 둘 다 누적하지 않습니다.
- medium만 `updatedAt`을 inline으로 보여줍니다.
- `pending / requiresAppOpen / failed / succeeded`는 `WalkWidgetSnapshot.actionState` overlay로만 표현합니다.

### TerritoryStatusWidget
- guest / empty / offline / syncDelayed 모두 공통 CTA budget을 사용합니다.
- medium의 지표 타일 3개는 동일 min-height와 padding을 공유합니다.
- small은 숫자 한 축만 강조하고, 목표/남은 면적은 medium에서만 확장해 보여줍니다.

### QuestRivalStatusWidget
- guest / empty CTA도 실제 버튼이지만 공통 CTA height budget을 따릅니다.
- small은 `quest title / progress / rank / next action / CTA`까지만 유지합니다.
- status detail은 small에서 1줄, medium에서 2줄까지만 허용합니다.
- `claimInFlight / claimFailed / claimSucceeded`는 상태 배지와 CTA 우선순위로만 분기합니다.

### HotspotStatusWidget
- 상단은 `상태 배지 + 반경 배지`만 허용합니다.
- small은 `활성도 제목 / 반경 설명 / 분포 요약`까지만 유지하고 정책 footnote는 medium 우선입니다.
- `privacyGuarded / offlineCached / syncDelayed`는 data body 아래 compact footer 규칙을 따릅니다.
- raw count 대신 단계, 분포 요약, 정책 footnote만 노출합니다.

## State matrix to audit

공통 대표 상태:
- `guestLocked`
- `emptyData`
- `memberReady`
- `offlineCached`
- `syncDelayed`

추가 상태:
- WalkControl: `walking`, `idle`, `pending`, `failed`, `requiresAppOpen`, `succeeded`
- QuestRival: `claimInFlight`, `claimFailed`, `claimSucceeded`
- Hotspot: `privacyGuarded`

## Zero-base clipping rule

다음은 허용하지 않습니다.
- 상단 텍스트 잘림
- 하단 CTA 프레임 침범
- badge와 CTA 충돌
- metric tile 높이 불일치
- detail/status가 CTA를 프레임 밖으로 밀어내는 배치

## Evidence rule

실기기 홈 화면 캡처는 아래 조합 기준으로 수집합니다.
- 4 widgets x 2 families x representative states
- 최소 증적 축
  - guest / empty / ready / delayed
  - action overlay 있는 WalkControl
  - privacyGuarded Hotspot
  - claimFailed QuestRival

캡처 증적은 preview만으로 대체하지 않습니다.
