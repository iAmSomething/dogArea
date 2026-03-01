# Cycle 167 - Rival Privacy Policy Stage1 확정 (2026-03-01)

## 1) 이슈
- 대상: #130 `[Task][Rival][Stage 1] 익명/프라이버시/동의 정책 확정`

## 2) 개발(문서/검증) 내용
Stage1 정책 이슈의 수용 기준을 판정 가능하게 만들기 위해 정책 문서와 자동 검증 스크립트를 추가했다.

### 추가 파일
- `docs/rival-privacy-policy-stage1-v1.md`
- `scripts/rival_privacy_policy_stage1_unit_check.swift`

### 수정 파일
- `scripts/ios_pr_check.sh` (신규 체크 스크립트 연결)
- `README.md` (정책 문서 링크 추가)

## 3) 정책 문서에서 확정한 핵심
1. 노출 판정 테이블(Allow/Deny)
- opt-in 상태
- `sample_count >= 20`
- 주간 30분/야간 60분 지연
- 민감 구역 마스킹
- 미성년/민감 계정 보호

2. 동의/철회 상태 전이
- `OFF -> ON_PENDING -> ON`
- `ON -> OFF_REVOKED -> OFF`
- `ON` 이외 상태에서 presence 송신 금지

3. 개인정보 보호 체크리스트
- 정밀 좌표/닉네임/강아지명 비노출
- 정책/RPC/문서 간 k-anon/지연값 일치
- opt-out 즉시 반영
- 감사 로그 추적 가능성

## 4) 테스트
1. 단일 체크
- `swift scripts/rival_privacy_policy_stage1_unit_check.swift` -> PASS

2. PR 체크
- `DOGAREA_SKIP_BUILD=1 ./scripts/ios_pr_check.sh` -> PASS

## 5) 결론
- #130의 수용 기준(판정 가능 문서, 상태 전이 일관성, 보호 리뷰 체크리스트)을 문서/체크 스크립트 기준으로 충족.
- Stage2(#131) 구현 시 본 Stage1 정책을 서버 집계/리더보드 계약의 기준값으로 사용.
