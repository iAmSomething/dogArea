# Release Real-Device Evidence Matrix v1

- Issue: #707
- Relates to: #270, #266

## 목적
- 실기기에서만 검증 가능한 표면을 release gate 기준으로 표준화한다.
- 스크린샷/로그/체크리스트 형식을 통일해서 반복 회귀를 추적 가능하게 만든다.

## 증적 기본 세트
- 기기 정보
  - device model
  - OS version
  - app build / commit
- 실행 조건
  - app state
  - auth state
  - network state
- 로그 증적
  - 최소 3줄
  - 관련 `request_id`가 있으면 포함
- 화면 증적
  - `step-1` 직후
  - `step-2` 최종 상태
  - 실패 시 `step-fail`
- 체크리스트
  - expected
  - actual
  - retry 여부
  - pass/fail/hold

## 파일명 규칙
- 스크린샷
  - `RD-001-step-1.png`
  - `RD-001-step-2.png`
  - `RD-001-step-fail.png`
- 로그
  - `RD-001-console.log`
- 체크리스트
  - `RD-001-checklist.md`

## 실기기 매트릭스
| Case ID | Surface | Device / OS | State | Expected | Required Evidence |
| --- | --- | --- | --- | --- | --- |
| `RD-001` | map 긴 산책 세션 | iPhone 실제 기기 / iOS 18+ | foreground -> background -> foreground | 장시간 세션 저장/요약 일치 | 스크린샷 2장 + 로그 + checklist |
| `RD-002` | 오프라인 후 복구 | iPhone 실제 기기 / iOS 18+ | offline -> online | outbox 재전송 순서/복구 성공 | 스크린샷 2장 + 로그 + checklist |
| `RD-003` | nearby-presence 오류/복구 | iPhone 실제 기기 / iOS 18+ | opt-in + error + recovery | 401/500/network loss 후 복구 | 스크린샷 2장 + 로그 + checklist |
| `RD-004` | widget start/end 상태 전이 | iPhone 실제 기기 / iOS 18+ | cold/background/foreground | 위젯/앱/Live Activity 수렴 | 스크린샷 2장 + 로그 + checklist |
| `RD-005` | watch start/addPoint/end | Apple Watch 실제 기기 / watchOS 11+ | connected / delayed sync | queue 손실 없이 동기화 | 스크린샷 2장 + 로그 + checklist |
| `RD-006` | watch 종료 요약 | Apple Watch 실제 기기 / watchOS 11+ | walk end | 종료 요약과 앱 상세 일치 | 스크린샷 2장 + 로그 + checklist |

## 체크리스트 표준 형식
| Field | Description |
| --- | --- |
| `Case ID` | `RD-xxx` |
| `Precondition` | 로그인/네트워크/앱 상태 |
| `Action` | 탭/버튼/상태 전이 |
| `Expected` | 기대 결과 |
| `Actual` | 실제 결과 |
| `Retry` | `none / retry-1 / retry-2` |
| `Final Status` | `PASS / FAIL / HOLD` |
| `Evidence Files` | 스크린샷/로그 파일명 |
| `Follow-up Issue` | 후속 이슈 번호 |

## 로그 표준
- map / nearby
  - `request_id`
  - `SupabaseHTTP`
  - `SyncOutbox`
- widget
  - `WidgetAction`
  - `onOpenURL received`
  - `consumePendingWidgetActionIfNeeded`
- watch
  - queue 적재/flush
  - action route
  - end summary 반영 로그

## 운영 규칙
- release 직전에는 `RD-001` ~ `RD-006` 중 변경 범위에 해당하는 케이스만 필수 수행
- `widget`이나 `watch` 미영향 PR은 해당 케이스를 `SKIPPED`로 남길 수 있다.
- `HOLD`는 flaky/infra 사유와 재실행 계획 없이 남길 수 없다.
