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
- `bash scripts/manual_blocker_evidence_status.sh widget --raw-errors`
- `bash scripts/manual_blocker_evidence_status.sh widget --apply-prefill`
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
- `incomplete`일 때 gap summary
  - plain text: `gap-summary`, `next-fill`, `gap-cases`/`gap-files`
  - markdown: `### Gap Summary`
  - `auth-smtp`는 scenario row 오류를 `03-live-send-results.md`로 접어서 실제 작성 파일 기준으로 보여준다.
- `widget`은 최신 simulator baseline도 함께 보여준다.
  - plain text: `simulator-baseline`
  - markdown: `### Simulator Baseline`
  - action regression 마지막 결과
  - layout fast smoke 마지막 결과
  - suite별 `coverage`
  - `simulator-coverage-summary`
  - baseline refresh 명령
- `widget`은 prefill 해석 결과도 함께 보여준다.
  - plain text: `prefill-device-os`, `prefill-app-build`
  - markdown: `Prefill Device / OS`, `Prefill App Build`
  - source는 `env`, `stub`, `connected-ios-device`, `xcodebuild-settings`, `missing`
- 다음 액션 명령
  - `next-render`
  - `next-prefill-existing`
  - `next-prefill-env`
  - `next-prefill-bootstrap`
  - `next-apply-prefill`
  - `next-validate`
  - `next-render-closure`
  - `next-archive`
  - `next-post-closure`
  - `next-post-closure-bundle` (`widget`만 제공)
- `--markdown` 모드에서는 위 내용을 reviewer 공유용 markdown report로 출력한다.
- `--output`을 같이 주면 report를 파일로 export하고 `WROTE <path>`를 출력한다.
- `--apply-prefill`를 주면 existing bundle에 대해 `prefill_manual_evidence_pack.sh`를 먼저 적용한 뒤 status를 계산한다.
- env가 비어 있어도 자동 감지로 메타를 해석할 수 있으면 `next-prefill-env`를 생략한다.
- env와 자동 감지 둘 다 비어 있으면 `next-prefill-env`로 `print_manual_evidence_prefill_env.sh` 경로를 먼저 안내한다.
- env가 비어 있으면 `next-prefill-bootstrap`으로 env template source + `--apply-prefill` one-shot 명령도 함께 안내한다.
- `auth-smtp`의 `next-render`는 `--prefill-from-env`를 포함해 운영 메타데이터 transcription 비용을 줄인다.
- `widget`의 `next-render`도 `--prefill-from-env`를 포함해 공통 기록 메타 transcription 비용을 줄인다.
- `widget` simulator baseline은 아래 스크립트들이 마지막 실행 결과를 `.codex_tmp/widget-simulator-baseline/`에 남긴 값을 읽는다.
  - `bash scripts/run_widget_action_regression_ui_tests.sh`
  - `bash scripts/run_pr_fast_smoke_widget_layout_checks.sh`
- widget suite와 `WD-*`, `WL-*` 케이스 매핑은 `docs/widget-simulator-baseline-coverage-matrix-v1.md`를 정본으로 사용한다.
- existing bundle에 metadata gap이 남아 있으면 `next-apply-prefill`를 우선 노출한다.
- existing bundle에 metadata gap이 남아 있고 env도 비어 있으면 `next-prefill-env -> next-apply-prefill -> next-validate`가 기본 경로다.
- 기존 bundle이 이미 있으면 `next-apply-prefill` 또는 `next-prefill-existing` -> `next-validate` 순서가 더 안전한 기본 경로다.
- 기본 출력은 validator raw dump를 숨기고 요약만 보여준다.
- `--raw-errors`를 주면 validator raw dump도 stderr로 그대로 출력한다.

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
  - simulator baseline (`widget`만)
  - gap summary (`incomplete`일 때만)
  - render / validate / archive / closure post 명령
