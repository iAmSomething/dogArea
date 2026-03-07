# Home Refresh Entrypoint v1

## 목적

홈 화면의 refresh 진입점을 trigger 기준으로 정리해서 같은 이벤트에서 `refreshIndoorMissions`, `syncSeasonScoreWithWalkSessions`, `refreshSeasonMotion`이 중복 실행되는 구조를 줄입니다.

## Trigger Matrix

| Trigger | Before entrypoint | Before expensive calls | After entrypoint | After expensive calls | 비고 |
| --- | --- | --- | --- | --- | --- |
| 홈 최초 진입 | `HomeViewModel.init -> fetchData` + `HomeView.onAppear -> fetchData` | `refreshIndoorMissions` / `syncSeasonScoreWithWalkSessions` / `refreshSeasonMotion` 각 4회 | `HomeViewModel.performInitialRefresh` | 세 계산 각 1회 | 첫 `onAppear`는 애니메이션/가시성 state만 동기화 |
| 홈 재노출(탭 복귀) | `HomeView.onAppear -> fetchData` | 세 계산 각 2회 | `HomeView.refreshForVisibleReentry` | 세 계산 각 1회 | 화면 재노출 시 full refresh 1회만 수행 |
| 앱 복귀(홈 visible) | 전용 진입점 없음 | 0회 또는 화면 재구성에 간접 의존 | `scenePhase == .active -> refreshForAppResumeIfNeeded` | 세 계산 각 1회 | launch 직후 첫 active 이벤트는 skip |
| 당겨서 새로고침 | `fetchData` | 세 계산 각 2회 | `fetchData -> executeRefresh(.manualRefresh)` | 세 계산 각 1회 | 카드 결과는 동일 |
| pet 전환(home source) | `selectPet -> applySelectedPetStatistics` + `selectedPetDidChange` sink | 세 계산 각 2회 | `selectPet -> refreshForSelectedPetChange` + sink ignore `home` source | 세 계산 각 1회 | 외부 source pet 전환은 여전히 1회 refresh |

## After 구조

1. 저장소 재조회 여부는 `HomeRefreshTrigger`가 결정합니다.
2. `applySelectedPetStatistics(refreshDerivedContent: false)`로 집계만 먼저 계산합니다.
3. 실내 미션/시즌/날씨 파생 상태는 `refreshIndoorMissions(now:)` 한 번으로 모읍니다.
4. 앱 복귀와 홈 재노출은 서로 다른 trigger로 나누되, launch 직후 duplicate refresh는 막습니다.
5. `selectedPetDidChangeNotification`는 `source == "home"`이면 자기 반사 refresh를 건너뜁니다.

## 유지한 사용자 계약

- 홈 카드 구성/문구/상태 결과는 유지합니다.
- 시즌/날씨/실내 미션 계산 순서는 `refreshIndoorMissions(now:)` 내부 계약을 그대로 사용합니다.
- time boundary 변경 시에도 타임존 메시지와 집계 결과는 유지합니다.
