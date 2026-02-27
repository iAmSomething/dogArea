# Cycle 124 Report — Season Weekly Policy Stage 1 (2026-02-27)

## 1. 대상
- Issue: `#124 [Task][Season][Stage 1] 주간 시즌 규칙/점수/감쇠 정책 확정`
- Branch: `codex/cycle-124-season-policy-stage1`

## 2. 구현 요약
- 시즌 Stage1 정책 문서 신규 작성
  - 주간 시즌 캘린더/정산 지연창(2시간) 확정
  - 점수 산식(신규 점령 +5, 동일 타일 유지 일 1회 +1) 명시
  - 감쇠 규칙(48시간 유예 후 하루 -2, 하한 0) 명시
  - 동점 처리 우선순위(활성 타일 -> 신규 점령 -> 마지막 기여 시각 -> user_id) 확정
  - 티어 컷(80/180/320/520) 및 보상(배지/프레임) 고정
- 운영 문서 연결
  - 스키마 명세에 Stage1 정책 고정 섹션 추가
  - 운영 검증 문서에 Stage1 정책 확인 SQL/기대값 추가
- 자동 검증 추가
  - Stage1 정책 문서/운영문서/README 링크 검증 스크립트 추가
  - 산식/감쇠/동점/티어 경계값 결정성 체크 포함

## 3. 변경 파일
- `docs/season-weekly-policy-stage1-v1.md`
- `docs/cycle-124-season-policy-report-2026-02-27.md`
- `docs/supabase-schema-v1.md`
- `docs/supabase-migration.md`
- `scripts/season_policy_stage1_unit_check.swift`
- `scripts/ios_pr_check.sh`
- `README.md`

## 4. 검증
- `swift scripts/season_policy_stage1_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- Stage1은 정책 고정 문서 중심이며, 시즌 스냅샷/보상 발급 영속화 테이블(`season_runs`, `season_user_scores`, `season_rewards`)은 Stage2(#125)에서 구현 필요.
