# CoreData Return Contract v1

## 1. 목적
- `savePolygon` / `deletePolygon` 호출 직후 UI 상태와 영속 데이터가 항상 동일하도록 반환 계약을 통일한다.

## 2. 계약
- `fetchPolygons()`:
  - CoreData 기준 전체 목록을 반환한다.
  - `createdAt` 오름차순으로 정렬된 결과를 반환한다.
- `savePolygon(polygon:)`:
  - 저장 시도 후 최신 `fetchPolygons()` 결과 전체 목록을 반환한다.
  - 저장 실패 시에도 현재 영속 상태(`fetchPolygons()`)를 반환한다.
- `deletePolygon(id:)`:
  - 삭제 시도 후 최신 `fetchPolygons()` 결과 전체 목록을 반환한다.
  - 대상이 없어도 현재 영속 상태(`fetchPolygons()`)를 반환한다.

## 3. 호출부 규칙(MapViewModel)
- save/delete 호출 뒤 별도 fetch를 중복 호출하지 않는다.
- 반환 목록을 단일 진실원으로 사용해 `polygonList`를 즉시 갱신한다.
- Heatmap 갱신은 `polygonList` 갱신 직후 수행한다.

## 4. 완료 기준
- 저장/삭제 직후 UI 목록과 CoreData 데이터가 일치한다.
- save/delete/fetch의 반환 의미가 문서-코드에서 동일하다.
