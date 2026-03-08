# 지도 퀘스트 피드백 HUD 정책 v1

## 목적
산책 중 퀘스트/미션 진행을 홈으로 돌아가지 않고도 이해할 수 있게 만들되, 지도 가시성과 조작성을 해치지 않는 피드백 체계를 고정합니다.

핵심 원칙은 `모달 Alert`가 아니라 `HUD + milestone toast + expandable checklist` 3계층입니다.

## 계층 역할

### 1. Companion HUD
- 지도 상단 overlay에 상시 유지되는 기본 피드백 계층입니다.
- `대표 미션 1개 + 추가 n개`만 요약합니다.
- 보여주는 정보는 최대 3줄입니다.
  - 미션명
  - 현재 진행도
  - 남은 조건 1줄 요약
- 기본 상태에서는 펼침(`expanded`)을 사용합니다.
- 자동 추적 신호가 여러 개면 `compactSingleLine`로 접습니다.
- `critical banner`가 올라오면 `hiddenByCriticalBanner`로 밀립니다.

### 2. Milestone Toast
- 아래 이벤트에서만 짧게 노출합니다.
  - 50% 도달
  - 조건 충족 직전(near completion)
  - 완료(completed)
  - 보상 가능(claimable)
- 토스트는 모두 `auto-dismiss`입니다.
- 중복 억제 window를 둡니다.
  - halfway: 45초
  - near completion: 45초
  - completed: 90초
  - claimable: 120초
- 기본 copy/haptic 정책
  - halfway: `절반 넘겼어요` + `progressPulse`
  - near completion: `거의 다 왔어요` + `progressPulse`
  - completed: `퀘스트 완료` + `completionSuccess`
  - claimable: `보상 받을 수 있어요` + `rewardReady`
- map에서는 상태만 알려주고, `즉시 보상 수령`은 하지 않습니다.

### 3. Expandable Checklist
- HUD 탭 시 바텀시트/드로어로 확장합니다.
- 섹션은 2개로 나눕니다.
  - `산책 중 바로 반영돼요`
  - `홈에서 직접 확인해요`
- 자동 추적 가능한 항목은 counting rule 중심으로 보여줍니다.
- 홈 전용 미션은 이유를 함께 명시합니다.
  - 예: 돌봄/훈련/정리 미션은 홈 보드에서 직접 체크

## 우선순위 규칙
1. `critical banner`
2. `quest companion HUD`
3. `passive status`

정리하면:
- 권한/복구/종료 제안 같은 파괴 가능성 안내가 항상 우선입니다.
- quest feedback는 산책 흐름을 보조하는 정보여야 하며, 조작을 막아서는 안 됩니다.
- `모달 Alert`는 권한/오류/파괴적 확인 예외 상황에만 남깁니다.

## Source of Truth 정렬
- Home: `localIndoorMissionBoard`
- Map: `serverCanonicalQuestSummary`
- Widget: `widgetMirrorOfServerSummary`

지도 HUD는 widget summary와 같은 서버 canonical quest summary를 재맥락화해서 씁니다.
즉, 지도용 별도 계산 로직을 새로 만드는 대신 기존 quest summary snapshot을 지도용 표현 정책에 맞게 소비합니다.

## 산책 중 자동 추적 가능 조건
`#464` 정책을 그대로 이어받습니다.
- 산책 시간
- 이동 거리
- 신규 점령 타일
- 유효 산책 지속 시간

## 홈 전용 직접 체크 항목
다음 카테고리는 지도에서 완료 처리하지 않습니다.
- `recordCleanup`
- `petCareCheck`
- `trainingCheck`

지도에서는 체크리스트 하단 섹션으로만 설명하고, 실제 조작은 홈 보드에서 이어집니다.

## 보상 처리 정책
- 지도: `보상 가능` 상태만 노출
- 홈: 실제 `보상 수령` 처리
- 위젯: claim route를 요청할 수는 있으나 canonical completion/claim state는 앱과 서버가 결정

따라서 map toast/HUD copy는 아래 원칙을 따릅니다.
- 허용: `보상 받을 수 있어요`, `홈 퀘스트 보드에서 이어집니다`
- 금지: `지금 바로 수령`, `자동 수령 완료`

## 작은 화면 / 다중 배너 규칙
- 기본은 대표 미션 1개만 유지
- 추가 미션은 `추가 n개 진행 중` 수준으로 축약
- 작은 화면에서 critical banner와 quest HUD가 충돌하면 HUD는 숨김
- toast는 상단 chrome 아래에 짧게 오버레이되며 지도 조작 hit-test를 막지 않음
- checklist는 사용자가 명시적으로 탭했을 때만 확장

## QA 시나리오
1. critical banner 동시 노출
- setup: 위치 권한 복구 banner + 자동 미션 진행
- expected: banner 우선, HUD 숨김 또는 축약, toast 지연

2. 자동 미션 3개 동시 진행
- setup: 1개는 90%, 2개는 중간 진행
- expected: 대표 1개 + 추가 n개, near completion toast 1회

3. completed -> claimable 전이
- setup: 완료 직후 claimable 상태 전이
- expected: completed toast 후 claimable toast 1회, 즉시 claim은 없음

4. 직접 체크 미션 혼합
- setup: 자동 미션 1개 + 홈 전용 직접 체크 2개
- expected: map HUD는 자동 미션만, checklist 하단에 홈 전용 섹션

## 후속 이슈 연결
- `#467`: companion HUD 최소 정보셋/축약 규칙 구체화
- `#468`: critical banner와 동시 노출 우선순위/접힘 규칙 런타임 반영
- `#453`: 홈 미션 lifecycle/완료 흐름과 copy 정합성 유지
