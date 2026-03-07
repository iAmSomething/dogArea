# Home Mission Pet Context Snapshot v1

## 목적

홈 `refreshIndoorMissions(now:)`가 같은 입력으로 반복 호출될 때, 실내 미션 반려견 컨텍스트 집계(`최근 14일 일평균 산책 시간`, `최근 28일 주평균 산책 횟수`)를 매번 다시 `filter/reduce`하지 않도록 snapshot/cache 계약을 명시합니다.

## 명시적 입력

실내 미션 pet context 집계의 입력은 아래 3가지입니다.

1. `polygonList`
   - 이미 선택 반려견/전체 보기 정책이 반영된 홈 polygon 목록
2. `selectedPetId`
   - 현재 선택 반려견 식별자
3. `reference`
   - 최근 14일/28일 경계 계산의 기준 시각

`petName`, `ageYears`는 집계 입력이 아니라 최종 프레젠테이션 합성 입력입니다. 따라서 집계 snapshot은 재사용하되, 최종 `IndoorMissionPetContext` 조립 시점에는 항상 현재 `selectedPet` 표시 정보를 다시 읽습니다.

## Snapshot 계약

- `HomeIndoorMissionPetContextSnapshotService`는 `polygonList`의 order-independent fingerprint를 생성합니다.
- `applySelectedPetStatistics(...)`는 새 `polygonList`가 만들어질 때만 fingerprint를 갱신합니다.
- fingerprint가 이전과 같으면 기존 snapshot을 보존합니다.
- `refreshIndoorMissions(now:)`는 아래 조건을 모두 만족할 때만 snapshot을 재사용합니다.
  - fingerprint 동일
  - `selectedPetId` 동일
  - `reference >= computedAt`
  - `reference <= validThrough` 또는 `validThrough == nil`

## Stale 허용 범위와 갱신 조건

이 snapshot은 TTL 고정값이 아니라, **결과가 실제로 바뀔 수 있는 가장 이른 시간 경계**를 `validThrough`로 저장합니다.

- 최근 14일 평균에 포함된 polygon은 `createdAt + 14d`까지 결과에 영향이 있습니다.
- 최근 28일 주평균 횟수에 포함된 polygon은 `createdAt + 28d`까지 결과에 영향이 있습니다.
- `validThrough`는 위 두 경계 중 가장 이른 시각입니다.
- 포함된 polygon이 하나도 없으면 시간 경계로 인한 만료가 없으므로 `validThrough == nil`입니다.

즉 stale 허용 범위는 다음과 같습니다.

- 같은 `polygonList` / `selectedPetId`에서
- `reference`가 `computedAt ... validThrough` 구간 안에 있으면
- 기존 14일/28일 계산 결과를 그대로 재사용합니다.

`reference`가 `validThrough`를 **초과하는 순간**에만 재집계합니다. 경계 시각과 정확히 같은 경우(`reference == validThrough`)는 기존 `>= cutoff` 규칙과 동일하게 재사용 가능합니다.

## 결과 동일성

기존 계산식은 유지합니다.

- `recentDailyMinutes = recent14DayWalkingMinutes / 14`
- `averageWeeklyWalkCount = recent28DayPolygonCount / 4`
- window membership 기준도 동일하게 `createdAt >= cutoff`를 유지합니다.

따라서 난이도 정책, 쉬운 날 규칙, 카드 문구/내용은 변경하지 않습니다.

## 비용 비교

| 상황 | Before | After |
| --- | --- | --- |
| `refreshIndoorMissions(now:)` 1회 cache miss | `polygonList.filter` 2회 + `reduce` 1회 | 동일 |
| 같은 입력으로 `refreshIndoorMissions(now:)` 재호출 | 호출마다 `filter` 2회 + `reduce` 1회 반복 | `canReuseSnapshot` O(1) 판정 후 `filter/reduce` 0회 |
| `polygonList` 재구성 | 별도 입력 추적 없음 | fingerprint 1회 재계산 후 변경 시에만 snapshot 무효화 |

정리하면, 같은 홈 입력에서 반복 refresh가 들어와도 집계 본연의 비용은 첫 cache miss 1회로 제한됩니다.
