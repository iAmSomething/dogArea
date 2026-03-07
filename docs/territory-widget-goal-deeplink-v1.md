# Territory Widget Goal Deeplink v1

## 1. 목적
영역 위젯을 단순 수치 확인 표면이 아니라 `다음 목표 상세` 진입점으로 정리한다.

기본 원칙:
- small / medium 모두 탭 시 동일한 기본 목적지 사용
- 기본 목적지는 `TerritoryGoalView`
- 홈 루트에서 멈추지 않고, 바로 "다음에 뭘 해야 하는지"가 보이는 화면으로 연결

## 2. 기본 진입 경로
위젯 탭 기본 목적지:
- `dogarea://widget/territory?destination=goal_detail&territory_status=<status>`

앱 라우팅:
1. `RootView`가 영역 위젯 딥링크를 파싱
2. 홈 탭으로 전환
3. `HomeView`가 외부 라우트를 소비
4. `TerritoryGoalView`를 직접 push

## 3. 상태별 fallback
| 위젯 상태 | 기본 목적지 | fallback 동작 | 사용자에게 보일 핵심 맥락 |
| --- | --- | --- | --- |
| `memberReady` | `TerritoryGoalView` | 없음 | 남은 면적, 최근 정복, 다음 목표 |
| `offlineCached` | `TerritoryGoalView` | 최근 스냅샷 배너 표시 | 오프라인 스냅샷 기준임을 명시 |
| `syncDelayed` | `TerritoryGoalView` | 지연 배너 표시 | 새로고침 필요 안내 |
| `emptyData` | `TerritoryGoalView` | empty 안내 배너 표시 | 첫 영역 확장 유도 |
| `guestLocked` | 로그인/회원 전환 후 `TerritoryGoalView` | 인증 overlay 우선 | 로그인 후 바로 목표 상세로 복귀 |

## 4. 역할 분리
홈 카드 역할:
- 빠른 스캔
- 현재/다음/남은 면적 요약
- 상세 화면 진입 유도

영역 위젯 역할:
- 앱 바깥에서 다음 목표 상세로 바로 점프
- 상태별 fallback 배너를 통해 현재 문맥을 끊기지 않게 전달
- 홈 루트를 다시 스캔하게 만들지 않음

## 5. UX 원칙
1. 위젯 탭 후 사용자는 1단계 추가 탐색 없이 `TerritoryGoalView`를 본다.
2. 게스트 상태는 인증 이후에도 목적지를 잃지 않는다.
3. stale 상태는 detail 화면 상단 배너에서 바로 설명한다.
4. `AreaDetailView`는 위젯 기본 목적지가 아니라 `TerritoryGoalView` 내부 2단계 CTA로 유지한다.

## 6. QA 체크
1. `memberReady` route로 앱 실행 시 `screen.territoryGoal` 표시
2. `guestLocked` route는 로그인 요구 후 상세 목적지 유지
3. `offlineCached` / `syncDelayed` route는 상단 배너 노출
4. 영역 위젯 탭이 홈 루트에만 머무르지 않음
