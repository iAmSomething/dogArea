# Manual Evidence Archive Export v1

- Issue: #764
- Relates to: #731, #692, #617, #482

## 목적
- validator를 통과한 manual evidence bundle을 reviewer 전달용 archive로 한 번에 묶는다.
- closure comment preview와 source bundle을 같이 보관해 검토자가 디렉터리 구조를 직접 재조립하지 않게 한다.

## 엔트리포인트
- 스크립트: `bash scripts/archive_manual_evidence_pack.sh`

## 지원 모드
- `widget`
  - 입력: `.codex_tmp/widget-real-device-evidence/` 같은 validated bundle 디렉터리
  - 출력 기본값: `.codex_tmp/widget-real-device-evidence-export.zip`
- `auth-smtp`
  - 입력: `.codex_tmp/auth-smtp-evidence/` 같은 validated bundle 디렉터리
  - 출력 기본값: `.codex_tmp/auth-smtp-evidence-export.zip`

## 사용법
- widget
  - `bash scripts/archive_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence`
- auth-smtp
  - `bash scripts/archive_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence`
- 출력 경로 지정
  - `bash scripts/archive_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence --output .codex_tmp/widget-export.zip`
- staging 디렉터리 보존
  - `bash scripts/archive_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence --staging-dir .codex_tmp/auth-smtp-export`

## 동작 순서
1. `bash scripts/validate_manual_evidence_pack.sh <surface> <bundle-dir>` 로 bundle 완결성을 확인한다.
2. `bash scripts/render_closure_comment_from_evidence.sh <surface> <bundle-dir>` 로 closure preview를 생성한다.
3. 아래 구조를 staging 디렉터리에 만든다.
   - `README.md`
   - `widget-closure-comment.md` 또는 `auth-smtp-closure-comment.md`
   - `MANIFEST.md`
   - `SHA256SUMS`
   - `bundle/`
4. staging 내용을 zip archive로 묶는다.

## 출력 규칙
- archive에는 아래만 포함한다.
  - export `README.md`
  - closure comment preview
  - `MANIFEST.md`
  - `SHA256SUMS`
  - 원본 evidence bundle 전체 복사본
- `MANIFEST.md`에는 surface, issue, source bundle, export file 목록, bundle file listing을 기록한다.
- `SHA256SUMS`에는 `README.md`, closure preview, `MANIFEST.md`, `bundle/` 하위 모든 파일의 sha256을 기록한다.
- validator 실패 시 archive를 만들지 않는다.

## 운영 규칙
- archive는 review/전달 artifact다. blocker close 자체를 대신하지 않는다.
- widget는 여전히 실기기 screenshot/video 증적이 필요하다.
- auth-smtp는 여전히 provider/DNS/live-send 운영 증적이 필요하다.
