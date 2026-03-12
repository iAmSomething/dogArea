# Manual Closure Comment Poster v1

- Issue: #684
- Relates to: #408 (closed umbrella), #482

## 목적
- validator와 renderer를 통과한 evidence를 GitHub issue comment로 바로 게시한다.
- 잘못된 surface/issue 조합으로 닫는 실수를 막는다.

## 엔트리포인트
- 스크립트: `bash scripts/post_closure_comment_from_evidence.sh`

## 지원 surface / issue 조합
- `widget` -> single issue `#408`, `#617`, `#692`, `#731`
- `widget --all-related` -> active blockers `#731`, `#617`, `#692`
- `auth-smtp` -> `#482`

## 사용법
- widget dry-run
  - `bash scripts/post_closure_comment_from_evidence.sh widget --issue 408 .codex_tmp/widget-real-device-evidence`
- widget bundle dry-run
  - `bash scripts/post_closure_comment_from_evidence.sh widget --all-related .codex_tmp/widget-real-device-evidence`
- widget post
  - `bash scripts/post_closure_comment_from_evidence.sh widget --issue 731 .codex_tmp/widget-real-device-evidence --post`
- widget bundle post
  - `bash scripts/post_closure_comment_from_evidence.sh widget --all-related .codex_tmp/widget-real-device-evidence --post`
- auth-smtp dry-run
  - `bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue 482 .codex_tmp/auth-smtp-evidence`
