# Manual Closure Comment Renderer v1

- Issue: #676
- Relates to: #408, #482

## 목적
- validated evidence를 최종 종료 코멘트 형태로 빠르게 변환한다.
- 위젯은 다건 evidence를 case 단위로 집계하고, auth-smtp는 운영 evidence에서 provider/dns/positive case를 자동 채운다.
- 마지막 수작업을 줄이되, 실제 실증 결과 입력 자체는 사용자가 유지한다.

## 엔트리포인트
- 스크립트: `bash scripts/render_closure_comment_from_evidence.sh`

## 지원 모드
- `widget`
  - 입력: validated widget evidence 파일 8개가 들어있는 디렉터리 또는 단일 파일
  - 요구사항:
    - 모든 `WD-001` ... `WD-008` evidence가 있어야 함
    - 각 파일은 validator를 통과해야 함
    - 각 파일은 `Pass`여야 함
  - 출력:
    - `#408` 종료 코멘트 초안
- `auth-smtp`
  - 입력: validated auth smtp evidence 파일 1개
  - 추가 플래그:
    - `--negative-guard "<text>"`
    - `--negative-provider-event "<text>"`
  - 출력:
    - `#482` 종료 코멘트 초안

## 사용법
- 위젯
  - `bash scripts/render_closure_comment_from_evidence.sh widget .codex_tmp/widget-evidence-dir`
  - `bash scripts/render_closure_comment_from_evidence.sh widget .codex_tmp/widget-evidence-dir --write`
- auth-smtp
  - `bash scripts/render_closure_comment_from_evidence.sh auth-smtp .codex_tmp/auth-smtp-evidence-pack.md --negative-guard "SMTP-101: cooldown suppressed with retry_after_seconds=60" --negative-provider-event "SMTP-102: bounce observed in provider dashboard" --write`

## 출력 규칙
- 기본은 stdout 출력
- `--write` 기본 경로
  - widget: `.codex_tmp/widget-action-closure-comment.md`
  - auth-smtp: `.codex_tmp/auth-smtp-closure-comment.md`
- `--output <path>`로 별도 경로 지정 가능

## 운영 규칙
- renderer는 validator 통과 전 evidence를 받지 않는다.
- renderer가 comment body를 만든다고 해서 이슈를 자동 종료하지는 않는다.
- `#408`, `#482` 종료 전에는 실제 로그/스크린샷/실수신 결과가 채워졌는지 최종 검토가 필요하다.
