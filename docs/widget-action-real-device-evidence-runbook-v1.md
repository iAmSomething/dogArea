# Widget Action Real-Device Evidence Runbook v1

- Issue: #662
- Relates to: #408

## 목적
- 실기기 위젯 액션 검증 결과를 저장소 기준으로 일관되게 남긴다.
- `pass/fail`만 적는 대신 로그, 스크린샷, request_id, 앱 상태를 함께 남긴다.
- `#408` 종료에 필요한 manual QA evidence를 재현 가능한 형식으로 고정한다.

## 선행 문서
- 검증 축 정의: `docs/widget-action-real-device-validation-matrix-v1.md`
- 복붙용 기록 템플릿: `docs/widget-action-real-device-evidence-template-v1.md`
- 종료 체크리스트: `docs/widget-action-closure-checklist-v1.md`
- helper: `bash scripts/render_manual_evidence_pack.sh widget --write`
- 자동 회귀 러너: `bash scripts/run_widget_action_regression_ui_tests.sh`

## 최소 증적 세트
- 실제 기기 정보
  - 기기 모델
  - iOS 버전
  - 위젯 family
- 실행 조건
  - `cold start` / `background` / `foreground`
  - `로그인` / `로그아웃` / `auth overlay`
  - 액션 route 이름
- 로그 증적
  - `WidgetAction`
  - `onOpenURL received`
  - `consumePendingWidgetActionIfNeeded`
  - 가능하면 `request_id`
- 화면 증적
  - 위젯 탭 직후 화면
  - 최종 도착 화면
  - 실패 시 에러/오버레이 상태

## 로그 캡처 규칙
- 디버그 빌드 기준으로 Xcode console 또는 Devices log를 사용한다.
- 아래 문자열이 그대로 보여야 한다.
  - `WidgetAction`
  - `onOpenURL received`
  - `consumePendingWidgetActionIfNeeded`
- request correlation이 가능한 경우 `request_id`를 함께 기록한다.
- 로그는 최소 3줄 이상 남긴다.
  - 위젯 액션 수신
  - pending action consume 또는 defer
  - 최종 라우트/상태 수렴

## 스크린샷 규칙
- 각 케이스마다 최소 2장
  - `step-1`: 위젯 액션 직후
  - `step-2`: 최종 도착 화면
- 실패 케이스는 추가 1장
  - `step-fail`: 오버레이/잘못된 탭/미수렴 상태
- 파일명 규칙
  - `WD-001-step-1.png`
  - `WD-001-step-2.png`
  - `WD-001-step-fail.png`

## 실행 절차
1. `docs/widget-action-real-device-validation-matrix-v1.md`에서 대상 케이스를 고른다.
2. 앱 상태를 `cold start` / `background` / `foreground` 중 하나로 맞춘다.
3. 인증 상태를 `로그인` / `로그아웃` / `auth overlay` 중 하나로 맞춘다.
4. 위젯을 탭하거나 위젯 액션을 실행한다.
5. 즉시 스크린샷 `step-1`을 저장한다.
6. Xcode console에서 `WidgetAction` 로그와 `onOpenURL received` 로그를 캡처한다.
7. 최종 도착 화면에서 `step-2`를 저장한다.
8. `docs/widget-action-real-device-evidence-template-v1.md` 형식으로 결과를 기록한다.
9. 이슈 또는 PR 코멘트에 템플릿 본문과 스크린샷/로그를 함께 남긴다.

## Pass 기준
- 기대한 탭/상세 화면에 도착한다.
- 로그에 `WidgetAction`과 `onOpenURL received`가 남는다.
- pending action이 있는 경로는 `consumePendingWidgetActionIfNeeded` 또는 defer/replay 흔적이 남는다.
- auth overlay가 필요한 경우 즉시 실패하지 않고 의도된 defer 동작으로 수렴한다.

## Fail 기준
- 다른 탭/다른 화면으로 도착한다.
- 위젯 탭 후 아무 변화가 없다.
- 로그에 수신 흔적이 없거나 pending action consume 흔적이 없다.
- `auth overlay`가 필요한데 요청이 소실되거나 잘못된 상태로 종료된다.

## 운영 규칙
- `#408`을 닫을 때는 이 런북 형식으로 남은 실기기 evidence가 있어야 한다.
- simulator 결과는 참고 자료일 뿐, `real-device evidence` 대체물이 아니다.
- 새 widget action route를 추가하면 매트릭스와 템플릿을 같이 갱신한다.
