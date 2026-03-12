# Manual Blocker Evidence Status Runner v1

## 목적
- active widget blocker bundle과 `#482` Auth SMTP blocker의 현재 evidence 상태를 한 번에 점검한다.

## 대상 surface
- `widget` -> primary `#731`, related `#617`, `#692`
- `auth-smtp` -> `#482`

## 명령
- `bash scripts/manual_blocker_evidence_status.sh`
- `bash scripts/manual_blocker_evidence_status.sh widget`
- `bash scripts/manual_blocker_evidence_status.sh auth-smtp --write-missing`
- `bash scripts/manual_blocker_evidence_status.sh --markdown`
- `bash scripts/manual_blocker_evidence_status.sh --markdown --output .codex_tmp/manual-blocker-evidence-status.md`

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
  - `next-archive`
  - `next-post-closure`
  - `next-post-closure-bundle` (`widget`만 제공)
- `--markdown` 모드에서는 위 내용을 reviewer 공유용 markdown report로 출력한다.
- `--output`을 같이 주면 report를 파일로 export하고 `WROTE <path>`를 출력한다.
- `auth-smtp`의 `next-render`는 `--prefill-from-env`를 포함해 운영 메타데이터 transcription 비용을 줄인다.

## 기본 경로
- widget: `.codex_tmp/widget-real-device-evidence`
- auth-smtp: `.codex_tmp/auth-smtp-evidence`

## Markdown Report 구조
- `# Manual Blocker Evidence Status Report`
- generated timestamp (UTC)
- scope
- surface별 섹션
  - title
  - primary issue / related issues
  - evidence pack 경로
  - status
  - render / validate / archive / closure post 명령
