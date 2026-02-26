# Multi-Dog Context Sync v1

## 1. 목적
다견 사용자에서 반려견 선택 컨텍스트를 앱 전역(Home/Map/Setting/WalkList)으로 일관화하고, 산책 시작 전 자동 제안/1탭 전환으로 반복 선택 비용을 줄인다.

연결 이슈:
- 문서/구현: #69

## 2. 전역 컨텍스트 정책
- 선택 상태 저장소: `UserDefaults.selectedPetId`
- 변경 이벤트 브로드캐스트: `UserdefaultSetting.selectedPetDidChangeNotification`
- 화면 동기화:
  - Home/Map/Setting/WalkList ViewModel이 동일 알림을 구독해 `reloadUserInfo()`/`reloadSelectedPetContext()` 수행

## 3. 자동 제안 규칙(v1)
- 입력: 현재 로그인 사용자의 `pet[]`, 선택 히스토리 점수
- 점수 키: `weekday + timeSlot + petId`
  - `timeSlot`: `morning(05-10)`, `afternoon(11-16)`, `evening(17-21)`, `night(22-04)`
- 우선순위:
  1) 현재 요일+시간대 최고 점수 pet
  2) 최근 선택 pet
  3) 현재 선택 pet
  4) 첫 번째 pet

## 4. 1탭 스위처 정책
- 위치: 산책 시작 버튼 근처
- 조건: 비산책 상태 && pet 2마리 이상
- 동작: 탭 1회마다 다음 pet으로 순환 전환
- 로그: `walk_start_switcher` source로 선택 이벤트 기록

## 5. 이벤트 수집
- 분석 이벤트:
  - `pet_selection_changed`
  - `pet_selection_suggested`
- 로컬 이벤트 로그:
  - 최근 100건 ring-buffer 저장(디버그/QA 확인용)

## 6. 완료 기준 매핑
- 앱 재실행 후 마지막 선택 복원:
  - 기존 `selectedPetId` 유지 + 동기화 알림 구조로 일관성 보장
- 산책 시작 전 1탭 변경:
  - Start 버튼 근처 순환 스위처 제공
- 화면 간 불일치 0건:
  - 공통 알림 구독으로 상태 동기화

## 7. 선택 반려견 통계 집계 규칙 (v1.1 / #119)
- 산책 세션 저장 시 `WalkSessionMetadataStore`에 `petId`를 함께 기록한다.
- Home/WalkList 집계는 `selectedPetId` 기준으로 필터링된 세션만 사용한다.
- 레거시 데이터 fallback:
  - 기존 기록처럼 `petId`가 없는 세션만 존재하는 경우 전체 세션을 집계 대상으로 사용한다.
  - `petId`가 있는 세션이 하나라도 있는 사용자에서는 선택 반려견 일치 세션만 집계한다.
- 선택 반려견 변경 이벤트 수신 시 Home/WalkList 집계를 즉시 재계산한다.
