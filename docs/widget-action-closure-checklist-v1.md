# Widget Action Closure Checklist v1

- Issue: #668
- Relates to: #408, #617, #692, #731

## 목적
- `#408`을 닫기 전에 실제로 채워져야 하는 증적 항목을 한 문서에 고정한다.
- action convergence와 layout/clipping evidence가 분리돼 누락되는 일을 막는다.

## 선행 문서
- action matrix: `docs/widget-action-real-device-validation-matrix-v1.md`
- layout matrix: `docs/widget-family-real-device-validation-matrix-v1.md`
- action runbook: `docs/widget-action-real-device-evidence-runbook-v1.md`
- layout runbook: `docs/widget-family-real-device-evidence-runbook-v1.md`

## 필수 체크리스트
- action 실기기 검증 세트가 채워져 있다.
  - `WD-001`
  - `WD-002`
  - `WD-003`
  - `WD-004`
  - `WD-005`
  - `WD-006`
  - `WD-007`
  - `WD-008`
- layout 실기기 검증 세트가 채워져 있다.
  - `WL-001`
  - `WL-002`
  - `WL-003`
  - `WL-004`
  - `WL-005`
  - `WL-006`
  - `WL-007`
  - `WL-008`
- action 케이스에는 아래가 남아 있다.
  - `Device / OS`
  - `Widget Family`
  - `앱 상태`
  - `인증 상태`
  - `Action Route`
  - `Expected`
  - `Actual`
  - `Pass / Fail`
- layout 케이스에는 아래가 남아 있다.
  - `Widget Surface`
  - `Widget Family`
  - `Covered States`
  - `Headline Policy`
  - `Badge Budget`
  - `CTA Height Rule`
  - `Compact Formatting Rule`
  - `Pass / Fail`
- 로그 증적이 있다.
  - `WidgetAction`
  - `onOpenURL received`
  - `consumePendingWidgetActionIfNeeded`
- 스크린샷 증적이 있다.
  - `step-1`
  - `step-2`
  - 실패 케이스면 `step-fail`
- 실기기 결과가 simulator 결과와 혼용되지 않았다.
- 남은 실패 케이스가 있으면 blocker와 owner가 적혀 있다.

## 종료 판정
- 위 항목이 모두 채워졌고 실패 케이스가 없다면 `#408`, `#617`, `#692`, `#731`을 닫아도 된다.
- 실패 케이스가 남아 있으면 blocker를 닫지 않는다.
