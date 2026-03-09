# Map Top Slim HUD Safe Area v1

## 목표
- 산책 중 핵심 상태를 하단 조작 deck가 아니라 safe area 바로 아래 top chrome band에서 읽히게 만든다.
- 상단 HUD는 지도 시야를 거의 가리지 않는 `1~2줄` slim surface만 허용한다.
- 하단 control bar는 `조작`, 상단 HUD는 `상태`만 책임지도록 위계를 분리한다.

## 정보 계약
- 기본 노출 정보:
  - 경과 시간
  - 누적 영역
  - 포인트 수
  - 현재 반려견명 또는 산책 상태 제목
- title은 한 줄, status 보조 문구도 한 줄까지만 허용한다.
- metric pill은 `시간 / 영역 / 포인트` 3개를 기본으로 유지한다.

## 레이어 정책
- 산책 시작 전: 상단 slim HUD를 띄우지 않는다.
  - 시작 전 설명은 `map.walk.startMeaning.card`가 담당한다.
- 산책 중: `map.walk.activeValue.card`를 safe area 아래 top chrome에 띄운다.
- 저장 직후: `map.walk.savedOutcome.card`가 후속 행동을 담당하고, walking slim HUD는 내려간다.

## 동시 노출 우선순위
- 최상단 row:
  - 날씨 pill
  - 시즌 pill
  - 설정 버튼
- 그 아래 stack:
  - walking slim HUD
  - 시즌 summary/detail
  - banner
  - status overlay
- 배너/상태/시즌 상세가 경쟁하면 walking HUD는 `compact` 모드로 접는다.
- 상단에 별도 대형 설명 카드는 추가하지 않는다.

## 하단 control bar 분리
- `StartButtonView`의 walking 상태는 다음만 담당한다.
  - 좌측: 영역 context
  - 중앙: 시작/종료 CTA
  - 우측: 포인트 기록 방식 context
- 상단 HUD 내용을 다시 하단에 중복 노출하지 않는다.

## 회귀 기준
- `FeatureRegressionUITests/testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls`
- `swift scripts/map_top_slim_hud_safearea_unit_check.swift`
