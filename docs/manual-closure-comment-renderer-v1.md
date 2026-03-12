# Manual Closure Comment Renderer v1

- Issue: #676
- Relates to: #408, #482

## 목적
- validated evidence를 최종 종료 코멘트 형태로 빠르게 변환한다.
- widget은 action + layout bundle을 한 번에 집계한다.

## 엔트리포인트
- 스크립트: `bash scripts/render_closure_comment_from_evidence.sh`

## 지원 모드
- `widget`
  - 입력: validated widget evidence 디렉터리
  - 요구사항:
    - `WD-001` ... `WD-008` complete
    - `WL-001` ... `WL-008` complete
    - 모든 케이스가 `Pass`
  - 출력:
    - `#408`, `#617`, `#692`, `#731`에 공통으로 붙일 수 있는 closure comment 초안
- `auth-smtp`
  - 입력: validated auth smtp evidence 파일 1개

## 사용법
- `bash scripts/render_closure_comment_from_evidence.sh widget .codex_tmp/widget-real-device-evidence`
- `bash scripts/render_closure_comment_from_evidence.sh widget .codex_tmp/widget-real-device-evidence --write`
- `bash scripts/render_closure_comment_from_evidence.sh auth-smtp .codex_tmp/auth-smtp-evidence-pack.md --negative-guard "SMTP-101: cooldown suppressed with retry_after_seconds=60" --negative-provider-event "SMTP-102: bounce observed in provider dashboard" --write`
