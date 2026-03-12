# Manual Evidence Helper v1

- Issue: #672
- Relates to: #408, #482

## 목적
- blocker 상태인 manual evidence 이슈를 한 번에 시작할 수 있게 한다.
- 저장소에 이미 있는 runbook/template/checklist를 bundle skeleton으로 떨어뜨린다.
- 운영자나 QA가 문서 여러 개를 직접 오가며 복붙하는 비용을 줄인다.

## 엔트리포인트
- 스크립트: `bash scripts/render_manual_evidence_pack.sh`

## 지원 모드
- `widget`
  - 대상 이슈: `#408`, 관련 blocker `#617`, `#692`, `#731`
  - 출력: 디렉터리 bundle
  - 포함 문서
    - `docs/widget-action-real-device-evidence-runbook-v1.md`
    - `docs/widget-family-real-device-evidence-runbook-v1.md`
    - `docs/widget-action-real-device-validation-matrix-v1.md`
    - `docs/widget-family-real-device-validation-matrix-v1.md`
    - `docs/widget-action-closure-checklist-v1.md`
    - `docs/widget-action-closure-comment-template-v1.md`
- `auth-smtp`
  - 대상 이슈: `#482`
  - 출력: 단일 markdown 파일

## 사용법
- stdout으로 바로 보기
  - `bash scripts/render_manual_evidence_pack.sh widget`
  - `bash scripts/render_manual_evidence_pack.sh auth-smtp`
- `.codex_tmp/`에 기본 경로로 쓰기
  - `bash scripts/render_manual_evidence_pack.sh widget --write`
  - `bash scripts/render_manual_evidence_pack.sh auth-smtp --write`
- 원하는 경로로 쓰기
  - `bash scripts/render_manual_evidence_pack.sh widget --output .codex_tmp/widget-real-device-evidence`
  - `bash scripts/render_manual_evidence_pack.sh auth-smtp --output .codex_tmp/auth-smtp-pack.md`
- 채운 뒤 validator 실행
  - `bash scripts/validate_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence`
  - `bash scripts/validate_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence-pack.md`

## 출력 규칙
- 기본은 stdout 출력이다.
- `--write` 기본 경로
  - widget: `.codex_tmp/widget-real-device-evidence`
  - auth-smtp: `.codex_tmp/auth-smtp-evidence-pack.md`
- widget bundle에는 아래가 생성된다.
  - `README.md`
  - `action/WD-001.md` ... `action/WD-008.md`
  - `layout/WL-001.md` ... `layout/WL-008.md`

## 운영 규칙
- 이 helper는 evidence를 대신 채우지 않는다.
- `#408`, `#617`, `#692`, `#731`, `#482`는 실제 실기기/운영 증적이 들어오기 전까지 닫지 않는다.
