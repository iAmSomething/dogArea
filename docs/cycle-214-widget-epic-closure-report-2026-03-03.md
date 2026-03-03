# Cycle #214 위젯/Live Activity 1차 에픽 클로저 리포트 (2026-03-03)

- 에픽: #214 `[Epic][Widget] 산책 진입/요약 위젯 + Live Activity 1차`
- 브랜치: `codex/epic-214-widget-closure`
- 목적: 하위 이슈(215~219) 산출물을 묶어 에픽 완료 근거를 문서화하고 종료 기준을 정리한다.

## 1. 하위 이슈 완료 상태

1. #215 산책 시작/종료 인터랙티브 위젯
2. #216 산책 중 Live Activity + 종료 안전장치
3. #217 영역 현황(일/주) 위젯
4. #218 익명 핫스팟 위젯(프라이버시 가드)
5. #219 퀘스트/라이벌 진행 + 보상 진입 위젯

모든 하위 이슈는 2026-03-03 기준 `CLOSED` 상태다.

## 2. 에픽 DoD 매핑

1. 5개 하위 이슈 AC 충족
- 각 하위 이슈가 개별 PR로 머지 완료되어 main에 반영됨.

2. 잠금화면/홈화면/앱 내 상태 일관성 및 종료 누락 완화
- 위젯 AppIntent 액션 -> 앱 딥링크/액션 라우팅 경로가 일관되게 연결됨.
- Live Activity + 자동 종료/복구 경로가 기존 복구 정책(#78)과 연결됨.
- 정량 지표는 게임 레이어 관측 기준(#206) 기반으로 후속 모니터링한다.

3. 비회원/회원 프라이버시 노출 정책 위반 0건 유지
- 익명 핫스팟 위젯에서 좌표/정밀 카운트 미노출 정책 고정.
- `privacy_mode`/`suppression_reason` 매핑 문서를 추가해 위젯/앱 표현 기준을 통일.

## 3. 코드 경로 점검 포인트

1. `dogAreaWidgetExtension/WalkControlWidgetBundle.swift`
- `WalkControlWidget`, `TerritoryStatusWidget`, `HotspotStatusWidget`, `QuestRivalStatusWidget` 등록

2. `dogArea/Views/GlobalViews/BaseView/RootView.swift`
- 생명주기 시점별 위젯 스냅샷 동기화(`territory`, `hotspot`, `quest/rival`)
- 위젯 액션 라우팅(산책 시작/종료, 라이벌 탭, 보상 수령)

3. `dogArea/Source/Domain/Map/Services/MapClusterAnnotationService.swift`
- ActivityKit 기반 진행 상태 동기화 및 fallback 처리

## 4. 검증

1. `swift scripts/hotspot_widget_privacy_unit_check.swift`
2. `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

참고: 사용자 요청에 따라 디자인 감사 스크린샷 테스트(`run_design_audit_ui_tests.sh`)는 이번 사이클에서 실행하지 않았다.
