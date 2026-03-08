#478 Home Refresh Dedup Lightweight v1

## 배경
- `#478`은 홈 진입/재노출/앱 복귀/펫 전환/수동 새로고침 과정에서 실내 미션, 시즌, 날씨, 반려견 컨텍스트 계산이 조용히 중복 수행되던 경로를 줄이는 umbrella 이슈입니다.
- 실제 구현은 아래 하위 사이클에서 나눠 반영되었습니다.
  - `#453` 홈 미션 상태 라이프사이클/완료 상태 UX 정리
  - `#456` 홈 실시간 날씨 상세 카드 추가
  - `#457` weather snapshot/provider/store 공용 계약 도입
  - `#505` 홈 refresh entrypoint 정리
  - `#506` 홈 미션 pet context snapshot cache
- `#464`는 퀘스트 제품 정책 이슈로, 이번 성능 umbrella의 blocker가 아니라 후속 정책 정리 대상입니다.

## 목표
- 홈 카드와 사용자 체감 결과는 바꾸지 않습니다.
- 같은 refresh cycle에서 실내 미션, 시즌, 날씨 관련 expensive path가 여러 번 도는 구조를 줄입니다.
- 최근 14일/28일 반려견 컨텍스트 집계를 입력 기반 snapshot으로 재사용합니다.
- 날씨는 홈/지도/실내 미션이 같은 snapshot 계약을 공유하게 유지합니다.

## 적용 요약

### 1. Refresh entrypoint 통합
- `HomeRefreshTrigger`를 기준으로 최초 진입, 홈 재노출, 앱 복귀, 수동 새로고침, 펫 전환을 분리했습니다.
- `applySelectedPetStatistics(refreshDerivedContent: false)`로 집계와 파생 refresh를 분리했습니다.
- `selectedPetDidChangeNotification`에서 `source == "home"`이면 자기반사 refresh를 무시합니다.

### 2. 실내 미션 pet context snapshot 재사용
- `HomeIndoorMissionPetContextSnapshotService`가 `polygonList`의 order-independent fingerprint를 생성합니다.
- fingerprint, `selectedPetId`, `reference`, `validThrough`가 유지되면 최근 14일/28일 집계를 재사용합니다.
- 따라서 같은 홈 입력으로 `refreshIndoorMissions(now:)`가 반복돼도 `filter/reduce`를 다시 수행하지 않습니다.

### 3. 공용 weather snapshot 계약 유지
- `WeatherSnapshotStore`를 기준으로 홈/지도/실내 미션이 같은 날씨 snapshot을 읽습니다.
- 홈은 상세 카드용 presentation만 추가하고, 위험도/대체 정책은 기존 공용 snapshot 계약을 그대로 사용합니다.
- 즉 날씨 UI 확장은 있었지만 refresh 비용은 개별 provider 재호출이 아니라 공유 snapshot 재사용 경로를 따릅니다.

## Before / After 근거

### Refresh entrypoint
- Before
  - 홈 최초 진입: `refreshIndoorMissions` / `syncSeasonScoreWithWalkSessions` / `refreshSeasonMotion` 각 `4회`
  - 홈 재노출: 세 계산 각 `2회`
  - 수동 새로고침: 세 계산 각 `2회`
  - home source pet 전환: 세 계산 각 `2회`
- After
  - 홈 최초 진입: 세 계산 각 `1회`
  - 홈 재노출: 세 계산 각 `1회`
  - 앱 복귀: 세 계산 각 `1회`
  - 수동 새로고침: 세 계산 각 `1회`
  - home source pet 전환: 세 계산 각 `1회`

### Pet context 집계
- Before
  - 같은 입력으로 `refreshIndoorMissions(now:)`를 다시 호출할 때마다 `polygonList.filter` `2회` + `reduce` `1회`
- After
  - cache miss `1회` 이후에는 `canReuseSnapshot` O(1) 판정
  - 같은 입력 재호출 시 `filter/reduce` `0회`

### Weather snapshot
- Before
  - 홈/지도/실내 미션이 공용 상세 snapshot 계약 없이 각자 다른 해석으로 날씨 state를 소비할 여지가 있었습니다.
- After
  - `WeatherSnapshotStore`를 통해 같은 snapshot을 공유합니다.
  - 홈은 상세 카드 렌더링만 추가하고, 날씨 source of truth는 공용 snapshot으로 고정됩니다.

## 행동 보존 정리
- 홈 카드 배치와 디자인은 변경하지 않습니다.
- 미션 완료 기준, 시즌 정책, 날씨 위험 정책은 변경하지 않습니다.
- 홈 미션 완료/진행/날씨 상세 카드는 기존 하위 이슈에서 정리된 결과를 그대로 유지합니다.
- 이번 umbrella 문서는 성능 관점의 완료 근거와 회귀 게이트를 추가하는 역할만 합니다.

## 측정 근거 출처
- refresh 호출 수 비교: `docs/home-refresh-entrypoint-v1.md`
- pet context 비용 비교: `docs/home-mission-pet-context-snapshot-v1.md`
- 공용 날씨 snapshot 계약: `docs/weather-snapshot-provider-v1.md`

## 회귀 게이트
- `swift scripts/home_refresh_dedup_lightweight_unit_check.swift`
- `swift scripts/home_refresh_entrypoint_unit_check.swift`
- `swift scripts/home_mission_pet_context_snapshot_unit_check.swift`
- `swift scripts/weather_snapshot_provider_unit_check.swift`
- `swift scripts/home_mission_lifecycle_ux_unit_check.swift`
- `swift scripts/home_weather_detail_card_unit_check.swift`

## 관련 문서
- `docs/home-refresh-entrypoint-v1.md`
- `docs/home-mission-pet-context-snapshot-v1.md`
- `docs/weather-snapshot-provider-v1.md`

## 후속 분리 이슈
- `#464`는 산책 중 퀘스트 자동 체크/보상 흐름 정책 정리 이슈입니다.
- 이는 홈 refresh 경량화와 직접적인 blocker가 아니므로, `#478` 완료 후 별도 제품 정책 축으로 유지합니다.

## 결론
- `#478`의 핵심 요구사항인 refresh 중복 제거, pet context 경량화, shared weather snapshot 계약은 하위 이슈들로 모두 충족되었습니다.
- 이번 문서는 그 결과를 umbrella 기준으로 고정하고, 이후 홈 성능 회귀가 다시 들어오지 않도록 단일 게이트를 추가합니다.
