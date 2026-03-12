# Widget Action Real-Device Evidence Runbook v1

- Issue: #662
- Relates to: #408 (closed umbrella), #617, #731

## 목적
- 실기기 위젯 액션 검증 결과를 저장소 기준으로 일관되게 남긴다.
- `pass/fail`만 적는 대신 로그, 스크린샷, request_id, 앱 상태를 함께 남긴다.
- active blocker `#617`, `#731` 종료에 필요한 manual QA evidence를 재현 가능한 형식으로 고정한다.

## 선행 문서
- 검증 축 정의: `docs/widget-action-real-device-validation-matrix-v1.md`
- layout 축 정의: `docs/widget-family-real-device-validation-matrix-v1.md`
- helper: `bash scripts/render_manual_evidence_pack.sh widget --write`
- helper prefill: `bash scripts/render_manual_evidence_pack.sh widget --write --prefill-from-env`
- bundle validator: `bash scripts/validate_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence`
- 종료 체크리스트: `docs/widget-action-closure-checklist-v1.md`

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
  - asset 경로는 bundle root 기준 `assets/action/*.png`

## 실행 절차
1. `docs/widget-action-real-device-validation-matrix-v1.md`에서 대상 케이스를 고른다.
2. `bash scripts/render_manual_evidence_pack.sh widget --write`로 bundle skeleton을 만든다.
   - 공통 메타를 먼저 채우려면 `--prefill-from-env`를 같이 쓴다.
   - 지원 env: `DOGAREA_WIDGET_EVIDENCE_DATE`, `DOGAREA_WIDGET_EVIDENCE_TESTER`, `DOGAREA_WIDGET_EVIDENCE_DEVICE_OS`, `DOGAREA_WIDGET_EVIDENCE_APP_BUILD`
3. `action/WD-*.md`에서 해당 케이스 파일을 연다.
4. 앱 상태를 `cold start` / `background` / `foreground` 중 하나로 맞춘다.
5. 인증 상태를 `로그인` / `로그아웃` / `auth overlay` 중 하나로 맞춘다.
6. 위젯을 탭하거나 위젯 액션을 실행한다.
7. 즉시 스크린샷 `step-1`을 저장한다.
8. Xcode console에서 `WidgetAction`, `onOpenURL received`, `consumePendingWidgetActionIfNeeded` 로그를 캡처한다.
9. 최종 도착 화면에서 `step-2`를 저장한다.
10. 결과를 `action/WD-*.md`에 기록한다.
11. `step-1` / `step-2` / 필요 시 `step-fail` asset을 `assets/action/`에 같은 파일명으로 저장한다.
12. 모든 action/layout 케이스를 채운 뒤 `bash scripts/validate_manual_evidence_pack.sh widget <bundle-dir>`로 완결성과 asset 존재를 검사한다.

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
- active blocker를 닫을 때는 action evidence만 complete여도 부족하다. layout evidence `WL-*`까지 complete여야 한다.
- simulator 결과는 참고 자료일 뿐, `real-device evidence` 대체물이 아니다.
