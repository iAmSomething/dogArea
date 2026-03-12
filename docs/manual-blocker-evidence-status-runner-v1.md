# Manual Blocker Evidence Status Runner v1

## 목적
- `#408` widget blocker bundle과 `#482` Auth SMTP blocker의 현재 evidence 상태를 한 번에 점검한다.

## 대상 surface
- `widget` -> primary `#408`, related `#617`, `#692`, `#731`
- `auth-smtp` -> `#482`

## 명령
- `bash scripts/manual_blocker_evidence_status.sh`
- `bash scripts/manual_blocker_evidence_status.sh widget`
- `bash scripts/manual_blocker_evidence_status.sh auth-smtp --write-missing`

## 출력 계약
- canonical issue 번호와 state
- related issue 목록
- evidence pack 경로
- 현재 상태
  - `missing`
  - `incomplete`
  - `complete`
- 다음 액션 명령
  - `next-render`
  - `next-validate`
  - `next-render-closure`
  - `next-post-closure`
  - `next-post-closure-bundle` (`widget`만 제공)

## 기본 경로
- widget: `.codex_tmp/widget-real-device-evidence`
- auth-smtp: `.codex_tmp/auth-smtp-evidence-pack.md`
