# ViewModel Modernization v1

## 1. 목적
- ViewModel에서 View 전용 `@Environment` 의존을 제거한다.
- 상태 갱신 경로를 단일화해 중복/불일치를 줄인다.
- watch action 처리 책임을 분리해 가독성과 테스트 가능성을 높인다.

## 2. 범위
- `MapViewModel`
- `SettingViewModel`
- `WalkListViewModel`

## 3. 변경 원칙
- ViewModel은 `@Environment`를 직접 사용하지 않는다.
- 동일 상태(`polygonList`, `heatmapCells`)를 갱신하는 코드는 한 경로로 모은다.
- 메시지 파싱과 상태 변경 로직을 분리한다.

## 4. 적용 내용
1. 불필요 `@Environment` 제거
- 세 ViewModel에서 `@Environment(\.managedObjectContext)` 제거
- CoreData 접근은 `CoreDataProtocol` 기본 구현으로 유지

2. 상태 갱신 경로 단일화
- `MapViewModel`에 `reloadPolygonState()` 추가
- 산책 종료/삭제/초기 로딩 등에서 중복된 fetch+refresh 코드를 통합

3. watch action 책임 분리
- 문자열 switch 직접 처리 대신 `WatchIncomingAction` 타입으로 파싱
- `handleWatchPayload`는 입력 검증/중복 판단/metric 기록만 수행
- 실제 상태 변경은 `applyWatchAction(_:)`에서 담당

## 5. 완료 기준
- ViewModel 내부의 불필요 `@Environment` 선언 제거
- 상태 갱신 중복 코드 감소
- 기존 watch 동작(start/add/end) 기능 회귀 없음
