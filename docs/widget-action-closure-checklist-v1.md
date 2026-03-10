# Widget Action Closure Checklist v1

- Issue: #668
- Relates to: #408

## 목적
- `#408`을 닫기 전에 실제로 채워져 있어야 하는 증적 항목을 한 문서에 고정한다.
- 실기기 검증 결과가 있어도 누락 항목 때문에 다시 열리는 일을 막는다.

## 선행 문서
- validation matrix: `docs/widget-action-real-device-validation-matrix-v1.md`
- evidence runbook: `docs/widget-action-real-device-evidence-runbook-v1.md`
- evidence template: `docs/widget-action-real-device-evidence-template-v1.md`

## 필수 체크리스트
- 최소 실기기 검증 세트가 채워져 있다.
  - `WD-001`
  - `WD-002`
  - `WD-003`
  - `WD-004`
  - `WD-005`
  - `WD-006`
  - `WD-007`
  - `WD-008`
- 각 케이스에 아래가 남아 있다.
  - `Device / OS`
  - `Widget Family`
  - `앱 상태`
  - `인증 상태`
  - `Action Route`
  - `Expected`
  - `Actual`
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
- 위 항목이 모두 채워졌고, 실패 케이스가 없다면 `#408`을 닫아도 된다.
- 실패 케이스가 남아 있으면 `#408`은 닫지 않고 blocker 이슈를 새로 분리한다.

## 운영 규칙
- 새 widget action route가 추가되면 이 체크리스트와 validation matrix를 같이 갱신한다.
- closure comment는 `docs/widget-action-closure-comment-template-v1.md` 형식을 사용한다.
