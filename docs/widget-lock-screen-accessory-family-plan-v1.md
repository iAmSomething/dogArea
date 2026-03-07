# Widget Lock Screen Accessory Family Plan v1

- 대상 이슈: #511
- 관련 이슈: #408, #214
- 목적: 잠금 화면 accessory 계열 위젯에서 산책/영역/핫스팟/퀘스트 정보를 glance 중심으로 노출할 때의 정보 구조, 상태 축약, 딥링크 규칙을 고정한다.

## 1. 범위와 전제

1. 이번 문서는 `accessoryCircular`, `accessoryRectangular`, `accessoryInline` family에 무엇을 실을지 정의하는 제품 계약이다.
2. 기존 `systemSmall`, `systemMedium` 레이아웃은 유지한다. accessory family는 추가 범위이며 기존 홈 화면/StandBy surface를 대체하지 않는다.
3. accessory family는 `glance + tap-through`가 기본이다. 파괴적이거나 오동작 위험이 큰 직접 액션은 1차 범위에서 넣지 않는다.
4. 기존 snapshot/RPC 계약은 그대로 재사용한다. 이번 이슈 범위에서는 backend contract를 새로 추가하지 않는다.

## 2. Family 밀도 규칙

| family | 정보 밀도 | 상태 토큰 예산 | 탭 정책 |
| --- | --- | --- | --- |
| `accessoryCircular` | 아이콘/링 1개 + 핵심 숫자 1개 | 1~2글자 또는 기호 1개 | 탭 시 가장 자연스러운 화면으로 이동 |
| `accessoryRectangular` | 제목 1개 + 지표 1~2개 + 상태 1개 | 상태 배지 1개 + 보조 문장 1줄 | 탭 시 상세 맥락 화면으로 이동 |
| `accessoryInline` | 한 줄 요약 1개 | 12~14자 수준 | 탭 시 해당 기능의 진입점으로 이동 |

## 3. 위젯별 Family 정보 구조

| 위젯 | `accessoryCircular` | `accessoryRectangular` | `accessoryInline` | 기본 탭 동작 | 비고 |
| --- | --- | --- | --- | --- | --- |
| `WalkControlWidget` | 산책 중이면 경과 시간 링, 대기 중이면 `재생` 계열 glyph | 반려견 이름 + 산책 상태 + 경과 시간 또는 시작 준비 문구 | `산책 18분`, `산책 준비` | `지도` 탭 | accessory에서는 직접 시작/종료보다 현재 상태 glance와 지도 진입을 우선 |
| `TerritoryStatusWidget` | 오늘 점령 수 또는 주간 진행의 단일 수치 | 오늘/주간/방어 예정 중 우선 2개 지표 | `오늘 3 · 방어 1` | `홈 > 영역 목표` | member 전용 지표, guest면 로그인 유도 상태로 축약 |
| `HotspotStatusWidget` | `높음/보통/낮음/없음` 단계 중 하나만 표시 | 단계 + 보호/지연 정책 문구 1줄 | `주변 신호 보통` | `라이벌 > 익명 핫스팟` | 프라이버시 정책상 좌표/개별 카운트 미노출 유지 |
| `QuestRivalStatusWidget` | 보상 가능 시 선물 glyph, 아니면 퀘스트 진행률 또는 라이벌 순위 중 하나 | 퀘스트 진행 + 라이벌 순위/리그 | `퀘스트 3/5 · #2` | `라이벌` 탭 | 보상 수령 가능 상태는 라이벌 진입 후 claim context를 우선 |

## 4. 상태별 축약 규칙

| 상태 | `accessoryCircular` | `accessoryRectangular` | `accessoryInline` | 규칙 |
| --- | --- | --- | --- | --- |
| 산책 중 | `중`, 타이머 링 | `산책 중`, `18분` | `산책 18분` | 산책 위젯에서만 경과 시간 숫자를 직접 노출 |
| 대기 중 | `대기` 또는 `재생` glyph | `산책 준비` | `산책 준비` | 행동 유도보다 준비 상태를 먼저 설명 |
| 게스트 | `잠금` | `로그인 후 사용` | `로그인 후 보기` | member 전용 위젯은 guest 상태에서 개인화 수치 미노출 |
| 오프라인 | `오프` | `오프라인 데이터` | `오프라인 데이터` | 최신 시각은 rectangular에서만 보조 노출 |
| `empty` 내부 상태 | `준비` | `데이터 준비 중` | `준비 중` | 사용자에게는 `empty`를 직접 노출하지 않는다 |

### 추가 상태 메모

1. 핫스팟 `privacyGuarded`는 `보호 중` 배지/보조 문구로만 표현한다.
2. 퀘스트 `claimInFlight`, `claimFailed`, `claimSucceeded`는 accessory에서 긴 문구 대신 `수령 중`, `수령 실패`, `수령 완료`로 축약한다.
3. `syncDelayed`는 모든 accessory family에서 `지연` 또는 `동기화 지연` 의미를 유지한다.

## 5. 핫스팟 프라이버시 유지 규칙

`HotspotStatusWidget` accessory family는 [핫스팟 위젯 프라이버시 매핑 v1](hotspot-widget-privacy-mapping-v1.md)를 그대로 따른다.

1. 사용자 좌표, 정밀 위치, 개별 핫스팟 수, 클러스터 원시 카운트는 accessory family에서도 노출하지 않는다.
2. 허용되는 핵심 정보는 `높음/보통/낮음/없음` 단계와 보호/지연 안내 문구뿐이다.
3. `k_anon`, `sensitive_mask`, `delay` 의미는 홈 위젯과 accessory 위젯에서 동일해야 한다.
4. guest 상태에서는 익명 트렌드 소개형 문구만 보여주고 개인화된 주변 상태처럼 보이게 만들지 않는다.

## 6. 딥링크 규칙

| 위젯 | 기본 딥링크 목적지 | 인증 필요 시 처리 | 이유 |
| --- | --- | --- | --- |
| `WalkControlWidget` | `지도` 탭 | 인증 없이 바로 진입 | 산책 시작/종료/현재 세션과 가장 가까운 실행 맥락 |
| `TerritoryStatusWidget` | `홈 > 영역 목표` 상세 | 인증 오버레이 후 원래 목적지 유지 | 홈 요약 카드와 가장 자연스럽게 이어지는 상세 경로 |
| `HotspotStatusWidget` | `라이벌 > 익명 핫스팟` 섹션 | 인증 오버레이 후 원래 목적지 유지 | 익명 공유/주변 신호 컨텍스트가 라이벌 탭에 모여 있음 |
| `QuestRivalStatusWidget` | `라이벌` 탭 | 인증 오버레이 후 원래 목적지 유지 | 퀘스트 진행, 순위, 보상 수령 흐름이 한 화면에 모임 |

### 딥링크 세부 원칙

1. accessory family 탭은 기본적으로 `open screen` 동작이다.
2. `WalkControlWidget`만 예외적으로 지도 진입 후 기존 위젯 action router와 연동할 수 있지만, accessory 1차에서는 오동작 위험이 큰 직접 종료/보상 수령 버튼을 넣지 않는다.
3. member 전용 목적지에서 guest가 진입하면 `#408`에서 고정한 auth defer/replay 경로를 재사용한다.

## 7. 기존 Family 호환성

1. 기존 `systemSmall`, `systemMedium`는 그대로 유지한다.
2. accessory view 추가는 기존 위젯 body를 깨지 않도록 family 분기를 additive하게 넣는다.
3. `WalkLiveActivityWidget`은 이번 이슈 범위에 포함하지 않는다.
4. StandBy는 기존 `systemSmall/systemMedium` surface를 계속 사용하고, accessory family 추가가 StandBy 전용 레이아웃 변경을 요구하지 않는다.

## 8. 구현 우선순위

1. `WalkControlWidget`: 잠금 화면에서 체감 가치가 가장 커서 1순위
2. `TerritoryStatusWidget`: 숫자 glance 가치가 높고 상태 수가 단순해 2순위
3. `QuestRivalStatusWidget`: claim/랭크 상태 우선순위만 정리되면 3순위
4. `HotspotStatusWidget`: 프라이버시 가드가 가장 중요하므로 마지막에 정책 검증과 함께 반영

## 9. QA 체크포인트

1. 각 widget family가 `systemSmall/systemMedium`와 역할이 충돌하지 않아야 한다.
2. `accessoryCircular`에서 숫자/문구가 1개를 넘지 않아야 한다.
3. `accessoryInline`는 한 줄 glance만 제공해야 하며 버튼처럼 보이면 안 된다.
4. `HotspotStatusWidget` accessory에는 좌표/개별 카운트가 없어야 한다.
5. guest/offline/empty 상태는 내부 상태명이 아니라 사용자 문구로만 보여야 한다.
6. 탭 후 이동 화면이 위젯의 정보 주제와 일치해야 한다.
