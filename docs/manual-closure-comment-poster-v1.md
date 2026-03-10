# Manual Closure Comment Poster v1

- Issue: #684
- Relates to: #408, #482

## 목적
- validator와 renderer를 통과한 evidence를 GitHub issue comment로 바로 게시한다.
- 마지막 복붙 단계를 제거하되, 잘못된 surface/issue 조합으로 닫는 실수를 막는다.

## 엔트리포인트
- 스크립트: `bash scripts/post_closure_comment_from_evidence.sh`

## 지원 surface / issue 조합
- `widget` -> `#408`
- `auth-smtp` -> `#482`

다른 issue 번호로는 실행되지 않는다.

## 동작 순서
1. surface / issue 조합을 검증한다.
2. 기존 renderer를 호출해 closure comment를 만든다.
3. 기본값에서는 stdout으로 출력만 한다.
4. `--post`를 주면 `gh issue comment`로 실제 게시한다.

## 사용법
- widget dry-run
  - `bash scripts/post_closure_comment_from_evidence.sh widget --issue 408 .codex_tmp/widget-evidence-dir`
- widget post
  - `bash scripts/post_closure_comment_from_evidence.sh widget --issue 408 .codex_tmp/widget-evidence-dir --post`
- auth-smtp dry-run
  - `bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue 482 .codex_tmp/auth-smtp-evidence-pack.md --negative-guard "SMTP-101: cooldown suppressed with retry_after_seconds=60" --negative-provider-event "SMTP-102: bounce observed in provider dashboard"`
- auth-smtp post
  - `bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue 482 .codex_tmp/auth-smtp-evidence-pack.md --negative-guard "SMTP-101: cooldown suppressed with retry_after_seconds=60" --negative-provider-event "SMTP-102: bounce observed in provider dashboard" --post`

## 출력 규칙
- 기본은 dry-run이며 rendered comment만 출력한다.
- `--post`를 주면 `gh issue comment`를 호출한다.
- `--output <path>`를 주면 renderer 결과를 해당 경로에 남긴 뒤 dry-run/post를 진행한다.

## 운영 규칙
- 이 스크립트는 validator를 우회하지 않는다. 실제 검증은 renderer 내부에서 다시 강제된다.
- surface/issue canonical pair가 맞지 않으면 즉시 실패한다.
- 실제 issue close는 별도 판단으로 진행한다. 이 스크립트는 comment 게시까지만 담당한다.

## 테스트 seam
- `DOGAREA_GH_BIN`으로 `gh` 대체 바이너리를 주입할 수 있다.
- 로컬 계약 테스트는 fake `gh`로 `issue comment` 호출 인자를 검증한다.
