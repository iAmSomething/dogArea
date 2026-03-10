# Manual Evidence Validator v1

- Issue: #674
- Relates to: #408, #482

## 목적
- helper로 만든 evidence pack이 실제 closure 용도로 충분히 채워졌는지 빠르게 확인한다.
- 템플릿을 반쯤 채운 채 issue를 닫으려는 실수를 줄인다.
- `#408`, `#482` blocker를 끝내는 마지막 수동 단계에 실패를 더 앞단에서 잡는다.

## 엔트리포인트
- 스크립트: `bash scripts/validate_manual_evidence_pack.sh`

## 지원 모드
- `widget`
  - 대상: `#408`
  - 입력: 실기기 결과를 채운 markdown 파일
  - 검사:
    - 메타/실행 조건/결과 필수 줄 비어있지 않음
    - `step-1`, `step-2` 스크린샷 경로 존재
    - `WidgetAction`, `onOpenURL received`, `consumePendingWidgetActionIfNeeded`, `request_id=` 로그 존재
    - 템플릿 placeholder literal이 그대로 남아있지 않음
- `auth-smtp`
  - 대상: `#482`
  - 입력: 운영 증적을 채운 markdown 파일
  - 검사:
    - DNS / SMTP 설정 / rollback 필드 비어있지 않음
    - `signup confirmation`, `password reset`, `email change` 시나리오 행이 전부 채워짐
    - pass/fail 및 blocker 결론 필드 존재

## 사용법
- helper로 pack 생성
  - `bash scripts/render_manual_evidence_pack.sh widget --write`
  - `bash scripts/render_manual_evidence_pack.sh auth-smtp --write`
- evidence를 채운 뒤 validator 실행
  - `bash scripts/validate_manual_evidence_pack.sh widget .codex_tmp/widget-action-evidence-pack.md`
  - `bash scripts/validate_manual_evidence_pack.sh auth-smtp .codex_tmp/auth-smtp-evidence-pack.md`

## 출력 규칙
- 성공 시
  - `PASS: widget evidence is complete`
  - `PASS: auth-smtp evidence is complete`
- 실패 시
  - non-zero exit
  - 누락된 필드/placeholder/미완성 scenario row를 항목별로 출력

## 운영 규칙
- validator 통과는 closure의 필요조건이지 충분조건은 아니다.
- `#408`은 실기기 결과 자체가 필요하고, `#482`는 실제 운영 SMTP 증적 자체가 필요하다.
- 템플릿 구조가 바뀌면 validator와 정적 체크를 같이 갱신한다.
