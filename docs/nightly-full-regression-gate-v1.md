# Nightly Full Regression Gate v1

- Issue: #707
- Relates to: #270, #266

## 목적
- fast smoke에서 다 못 보는 장시간/상태 전이/실기기 의존 회귀를 nightly에서 잡는다.
- nightly 범위와 실기기 증적 요구를 분리해서 release gate 운영 기준을 고정한다.

## fast smoke와의 경계
- fast smoke는 `빠른 차단`
- nightly는 `깊은 재현 + 증적 축적`
- nightly에서 반드시 포함할 것
  - 긴 산책 세션
  - 오프라인 후 복구
  - nearby-presence 오류/복구
  - widget 상태 전이
  - watch 큐/동기화/종료 요약
  - member full sweep / 5xx zero-budget 추세 확인

## Workflow binding
- GitHub Actions workflow: `.github/workflows/nightly-full-regression-gate.yml`
- runner: `bash scripts/run_nightly_full_regression_gate.sh`
- artifact root: `.artifacts/nightly-full-regression`
- artifact directory contract
  - `reports/`
  - `logs/`
  - `evidence/`
- manual blocker linkage
  - `bash scripts/manual_blocker_evidence_status.sh --write-missing`
  - `bash scripts/render_manual_evidence_pack.sh`
  - `bash scripts/validate_manual_evidence_pack.sh`
- nightly workflow는 실기기 전용 축을 무인화했다고 가정하지 않는다. 대신 sample artifact / blocker evidence / live smoke 결과를 한곳에 모아 다음 날 triage 가능하게 만든다.

## nightly 대상 축

| Axis ID | 축 | 자동화 | 실기기 필요 | 핵심 목표 |
| --- | --- | --- | --- | --- |
| `NF-001` | 긴 산책 세션 | 일부 자동 + 수동 증적 | 예 | 20분+ 세션에서도 저장/복구/요약이 무너지지 않는지 확인 |
| `NF-002` | 오프라인 후 복구 | 자동 + 수동 | 예 | session/points/meta/outbox 수렴 순서와 재전송 안정성 확인 |
| `NF-003` | nearby-presence 오류/복구 | 자동 + 수동 | 예 | 401/500/network loss 이후 banner/backoff/recovery 확인 |
| `NF-004` | widget 상태 전이 | 자동 + 실기기 | 예 | cold/background/foreground + auth state별 수렴 확인 |
| `NF-005` | watch 큐/동기화/종료 요약 | 자동 + 실기기 | 예 | watch queue 적재/flush/종료 요약 품질 확인 |

## 시나리오 정의

### NF-001 긴 산책 세션
- 최소 조건
  - 20분 이상
  - addPoint / auto record / stop alert / save까지 포함
- pass 기준
  - 세션 종료 후 홈/목록/상세/위젯 상태가 동일하게 반영
  - 메모리 폭증이나 세션 유실 없음

### NF-002 오프라인 후 복구
- 최소 조건
  - 오프라인 저장
  - 온라인 복귀
  - outbox 재전송
- pass 기준
  - `session -> points -> meta` 순으로 다시 밀림
  - 중복 저장/영구 pending 없음

### NF-003 nearby-presence 오류/복구
- 최소 조건
  - 401
  - 500
  - network loss
  - member full sweep 결과에서 unexpected `5xx` 0 유지
- pass 기준
  - session downgrade 오탐 없음
  - retry/backoff가 과호출 없이 동작
  - 복구 후 member 경로 200 재확인
  - `docs/member-supabase-http-5xx-zero-budget-gate-v1.md` 기준 위반 없음

### NF-004 widget 상태 전이
- 최소 조건
  - `cold start`
  - `background`
  - `foreground`
  - `로그인`
  - `로그아웃/auth overlay`
- pass 기준
  - action route가 소실되지 않음
  - 앱/위젯/Live Activity가 같은 상태로 수렴

### NF-005 watch 큐/동기화/종료 요약
- 최소 조건
  - watch start
  - addPoint
  - end
  - reconnect / retry
- pass 기준
  - watch queue 손실률이 허용 범위 내
  - 종료 요약 화면이 실제 저장 결과와 일치

## 산출물 규칙
- nightly 실행 결과는 아래 3종을 남긴다.
  - summary report
  - failing surface별 로그
  - 실기기 증적 매트릭스 업데이트
- 실기기 증적 기준 문서
  - `docs/release-real-device-evidence-matrix-v1.md`

## flaky 구간 재시도 / 보류 규칙
- 동일 축이 1회 실패하면 즉시 `retry 1회`
- 2회 연속 실패면 `FAIL`
- 아래 조건이면 `HOLD`
  - 외부 provider outage
  - 디바이스/OS 실험실 문제
  - known flaky tag가 이미 열린 이슈로 추적 중
- `HOLD`일 때도 실패 흔적과 근거 로그는 남긴다.

## nightly summary 형식
| Axis | Status | Retry | Real Device Evidence | Bucket |
| --- | --- | --- | --- | --- |
| `NF-001` | PASS | `0` | `RD-001` | - |

## bucket taxonomy
- `walk_long_session`
- `offline_recovery`
- `nearby_presence_recovery`
- `widget_state_transition`
- `watch_queue_sync`

## GO / NO-GO 규칙
- `NF-001`, `NF-002`, `NF-003` 중 하나라도 `FAIL`이면 `NO-GO`
- `NF-004`, `NF-005`는 release surface에 직접 영향이 있으면 `NO-GO`
- `HOLD`는 근거 이슈와 만료 시각 없이 남기지 않는다.
