# Manual Evidence Helper v1

- Issue: #672
- Relates to: #408, #482

## 목적
- blocker 상태인 manual evidence 이슈를 한 번에 시작할 수 있게 한다.
- 저장소에 이미 있는 runbook/template/checklist를 한 명령으로 합쳐서 보여주거나 `.codex_tmp/`에 떨어뜨린다.
- 운영자나 QA가 문서 여러 개를 직접 오가며 복붙하는 비용을 줄인다.

## 엔트리포인트
- 스크립트: `bash scripts/render_manual_evidence_pack.sh`

## 지원 모드
- `widget`
  - 대상 이슈: `#408`
  - 포함 문서
    - `docs/widget-action-real-device-evidence-runbook-v1.md`
    - `docs/widget-action-real-device-validation-matrix-v1.md`
    - `docs/widget-action-closure-checklist-v1.md`
    - `docs/widget-action-real-device-evidence-template-v1.md`
    - `docs/widget-action-closure-comment-template-v1.md`
- `auth-smtp`
  - 대상 이슈: `#482`
  - 포함 문서
    - `docs/auth-smtp-rollout-evidence-runbook-v1.md`
    - `docs/auth-smtp-live-send-validation-matrix-v1.md`
    - `docs/auth-smtp-closure-checklist-v1.md`
    - `docs/auth-smtp-rollout-evidence-template-v1.md`
    - `docs/auth-smtp-closure-comment-template-v1.md`

## 사용법
- stdout으로 바로 보기
  - `bash scripts/render_manual_evidence_pack.sh widget`
  - `bash scripts/render_manual_evidence_pack.sh auth-smtp`
- `.codex_tmp/`에 기본 파일로 쓰기
  - `bash scripts/render_manual_evidence_pack.sh widget --write`
  - `bash scripts/render_manual_evidence_pack.sh auth-smtp --write`
- 원하는 경로로 쓰기
  - `bash scripts/render_manual_evidence_pack.sh widget --output .codex_tmp/widget-pack.md`
  - `bash scripts/render_manual_evidence_pack.sh auth-smtp --output .codex_tmp/auth-smtp-pack.md`

## 출력 규칙
- 기본은 stdout 출력이다.
- `--write`를 주면 아래 기본 경로를 사용한다.
  - widget: `.codex_tmp/widget-action-evidence-pack.md`
  - auth-smtp: `.codex_tmp/auth-smtp-evidence-pack.md`
- `--output`을 주면 그 경로를 우선 사용한다.
- 출력에는 runbook/matrix/checklist 경로와 evidence template/closure comment template 본문이 함께 들어간다.

## 운영 규칙
- 이 helper는 evidence를 대신 채우지 않는다.
- `#408`, `#482`는 실제 실기기/운영 증적이 들어오기 전까지 닫지 않는다.
- template 경로가 바뀌면 이 helper와 정적 체크를 같이 갱신한다.
