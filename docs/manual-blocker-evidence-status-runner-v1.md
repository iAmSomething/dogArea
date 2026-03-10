# Manual Blocker Evidence Status Runner v1

## 목적

`#408` 위젯 실기기 증적과 `#482` Auth SMTP 운영 증적은 코드 변경보다 manual evidence 수집이 blocker입니다.

기존 helper는 각각 존재하지만 실제 운영에서는 아래가 흩어져 있습니다.

- evidence pack 생성
- evidence pack 완결성 검사
- closure comment 렌더링
- closure comment posting

이 문서는 blocker evidence를 한 번에 상태 점검하고, 다음 명령까지 바로 안내하는 통합 runner를 정의합니다.

## 대상 surface

- `widget` -> `#408`
- `auth-smtp` -> `#482`

둘 외의 surface는 이 러너 범위에 넣지 않습니다.

## 명령

- 전체 상태 조회
  - `bash scripts/manual_blocker_evidence_status.sh`
- 특정 surface만 조회
  - `bash scripts/manual_blocker_evidence_status.sh widget`
  - `bash scripts/manual_blocker_evidence_status.sh auth-smtp`
- evidence pack이 없으면 기본 경로에 즉시 생성
  - `bash scripts/manual_blocker_evidence_status.sh --write-missing`
  - `bash scripts/manual_blocker_evidence_status.sh widget --write-missing`

## 출력 계약

각 surface마다 아래를 출력합니다.

- canonical issue 번호와 현재 issue state
- evidence pack 경로
- 현재 상태
  - `missing`
  - `incomplete`
  - `complete`
- 다음 액션 명령 4개
  - `next-render`
  - `next-validate`
  - `next-render-closure`
  - `next-post-closure`

## 상태 의미

- `missing`
  - evidence pack 파일이 아직 없음
  - `next-render` 또는 `--write-missing`부터 시작
- `incomplete`
  - 파일은 있지만 validator를 통과하지 못함
  - evidence 입력 보강 후 `next-validate` 재실행
- `complete`
  - validator 통과
  - `next-render-closure` -> `next-post-closure` 순서로 종료 코멘트 작성 가능

## 기본 경로

- widget
  - `.codex_tmp/widget-action-evidence-pack.md`
- auth-smtp
  - `.codex_tmp/auth-smtp-evidence-pack.md`

환경 변수로 override 가능합니다.

- `DOGAREA_WIDGET_EVIDENCE_PATH`
- `DOGAREA_AUTH_SMTP_EVIDENCE_PATH`

## issue state 조회

기본적으로 `gh issue view`로 현재 상태를 읽습니다.

- `DOGAREA_SKIP_ISSUE_STATE=1`
  - 네트워크/CLI 의존 없이 상태 조회를 건너뜁니다.
- `DOGAREA_GH_BIN`
  - 커스텀 `gh` 바이너리 경로를 지정할 수 있습니다.

## 운영 권장 순서

1. `bash scripts/manual_blocker_evidence_status.sh --write-missing`
2. 생성된 pack에 실제 증적 입력
3. `bash scripts/manual_blocker_evidence_status.sh`
4. `status: complete`가 되면 `next-render-closure`
5. 최종 확인 후 `next-post-closure`

## 비범위

- 실제 SMTP provider / DNS 설정
- 실제 실기기 위젯 동작 검증 수행
- closure comment를 자동으로 바로 post 하는 배치 자동화

이 러너는 blocker evidence의 현재 상태를 가시화하고 다음 명령을 표준화하는 데만 집중합니다.
