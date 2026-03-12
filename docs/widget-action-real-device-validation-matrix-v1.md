# Widget Action Real-Device Validation Matrix v1

- Issue: #660
- Relates to: #408, #617, #731

## 목적
- 위젯 액션 경로의 실기기 검증 결과를 한 문서에 남긴다.
- simulator 자동 회귀와 분리된 real-device evidence 포맷을 고정한다.
- cold start / background / foreground / auth state / action 축을 누락 없이 기록한다.
- `#617`, `#731`에서 요구한 action convergence evidence를 `#408` closure pack으로 연결한다.

## 자동 회귀 진입점
- 전용 위젯 액션 UI 러너: `bash scripts/run_widget_action_regression_ui_tests.sh`
- 정적 게이트: `swift scripts/widget_action_regression_pack_unit_check.swift`
- 실기기 action 런북: `docs/widget-action-real-device-evidence-runbook-v1.md`
- 실기기 layout 런북: `docs/widget-family-real-device-evidence-runbook-v1.md`
- 종료 체크리스트: `docs/widget-action-closure-checklist-v1.md`

## 축 정의

### 앱 상태 축
- `cold start`: 앱이 완전히 종료된 상태에서 위젯 탭으로 진입
- `background`: 앱이 최근 task switcher에 남아 있는 상태에서 위젯 탭으로 복귀
- `foreground`: 앱이 이미 떠 있는 상태에서 위젯 액션을 재실행

### 인증 상태 축
- `로그인`: member 세션이 유효한 상태
- `로그아웃`: guest 또는 member 세션이 없는 상태
- `auth overlay`: 위젯 액션이 앱으로 넘어왔지만 인증 오버레이/로그인 요구로 defer 되는 상태

### 액션 축
- `open_rival_tab`
- `open_hotspot_broad`
- `open_quest_detail`
- `open_quest_recovery`
- `open_territory_goal`
- `walk_start`
- `walk_end`

## 최소 실기기 검증 세트

| Case ID | Device / OS | Widget Family | 앱 상태 | 인증 상태 | 액션 | 기대 결과 |
| --- | --- | --- | --- | --- | --- | --- |
| `WD-001` | iPhone 실제 기기 | `systemSmall` | `cold start` | `로그인` | `open_rival_tab` | 라이벌 탭으로 직접 진입하고 기본 상태가 보인다. |
| `WD-002` | iPhone 실제 기기 | `systemSmall` | `cold start` | `로그인` | `open_hotspot_broad` | 라이벌 탭이 3km preset 문맥으로 열린다. |
| `WD-003` | iPhone 실제 기기 | `systemMedium` | `background` | `로그인` | `open_quest_detail` | 홈 퀘스트 카드 위치로 이동하고 상세 배너가 보인다. |
| `WD-004` | iPhone 실제 기기 | `systemMedium` | `foreground` | `로그인` | `open_quest_recovery` | 홈 퀘스트 카드 위치로 이동하고 recovery 배너가 보인다. |
| `WD-005` | iPhone 실제 기기 | `systemMedium` | `cold start` | `로그인` | `open_territory_goal` | 목표 상세 화면으로 직접 진입하고 탭바는 숨겨진다. |
| `WD-006` | iPhone 실제 기기 | `systemSmall` | `cold start` | `로그인` | `walk_start` | 앱 세션이 위젯 start 요청을 소비하고 walking 상태로 수렴한다. |
| `WD-007` | iPhone 실제 기기 | `systemSmall` | `foreground` | `로그인` | `walk_end` | 앱 세션이 종료 요청을 소비하고 위젯/Live Activity 상태가 종료로 수렴한다. |
| `WD-008` | iPhone 실제 기기 | `systemSmall` | `cold start` | `로그아웃` | `walk_start` | 즉시 시작하지 않고 `auth overlay` 또는 로그인 진입으로 defer 된다. |

## 기록 템플릿
- helper가 생성한 bundle 디렉터리의 `action/WD-001.md` ... `action/WD-008.md`를 사용한다.
- 수동 기록이 필요하면 `docs/widget-action-real-device-evidence-template-v1.md` 형식을 따른다.

## 로그 확인 기준
- `WidgetAction` 디버그 로그가 남아야 한다.
- `onOpenURL received` 로그로 deep link 수신을 확인한다.
- `consumePendingWidgetActionIfNeeded` 또는 defer/replay 경로로 액션 소비 여부를 확인한다.
- 필요하면 `request_id` 또는 위젯 action route 문자열을 함께 남긴다.

## 운영 규칙
- `#408`을 닫을 때는 `WD-001` ... `WD-008` action evidence와 `WL-001` ... `WL-008` layout evidence가 모두 complete여야 한다.
- simulator 결과만으로는 `real-device validation` DoD를 충족하지 않는다.
- 새 widget action route를 추가하면 자동 회귀 스크립트와 이 문서, bundle skeleton을 같이 갱신한다.
