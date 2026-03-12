# Manual Evidence Validator v1

- Issue: #674
- Relates to: #408, #482

## 목적
- helper로 만든 evidence pack이 실제 closure 용도로 충분히 채워졌는지 빠르게 확인한다.
- 템플릿을 반쯤 채운 채 issue를 닫으려는 실수를 줄인다.

## 엔트리포인트
- 스크립트: `bash scripts/validate_manual_evidence_pack.sh`

## 지원 모드
- `widget`
  - 입력: widget evidence bundle 디렉터리
  - 검사:
    - `action/WD-001.md` ... `action/WD-008.md` 존재 및 완결
    - `layout/WL-001.md` ... `layout/WL-008.md` 존재 및 완결
    - action 케이스 로그/스크린샷 필드 완결
    - layout 케이스 budget/스크린샷 필드 완결
- `auth-smtp`
  - 입력: 운영 증적 markdown 파일

## 사용법
- `bash scripts/render_manual_evidence_pack.sh widget --write`
- `bash scripts/validate_manual_evidence_pack.sh widget .codex_tmp/widget-real-device-evidence`
- `bash scripts/render_closure_comment_from_evidence.sh widget .codex_tmp/widget-real-device-evidence --write`
- `bash scripts/post_closure_comment_from_evidence.sh widget --issue 408 .codex_tmp/widget-real-device-evidence --post`

## 출력 규칙
- 성공 시
  - `PASS: widget evidence is complete`
  - `PASS: auth-smtp evidence is complete`
- 실패 시
  - non-zero exit
  - 누락된 필드/파일/placeholder를 항목별로 출력
