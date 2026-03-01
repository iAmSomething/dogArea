# Cycle #127 Quest Stage1 Policy Report (2026-03-01)

## 1. 요약
- 이슈: #127
- 목표: 코스 퀘스트 템플릿/난이도 정책 문서 확정
- 결과: 정책 문서(v1)와 정적 검증 스크립트 추가 완료

## 2. 산출물
- 정책 문서: `docs/quest-stage1-template-difficulty-policy-v1.md`
- 검증 스크립트: `scripts/quest_stage1_policy_unit_check.swift`
- CI 연결: `scripts/ios_pr_check.sh`

## 3. 구현 포인트
- 퀘스트 타입 4종(`new_tile`, `linked_path`, `walk_duration`, `streak_days`) 정의
- 난이도 티어(`Easy/Normal/Hard`)와 보상 계수 표준화
- 일일 3개/주간 2개 생성 규칙 명시
- 중복 제한(최근 5슬롯 동일 타입 최대 2회)과 당일 중복 금지 규칙 명시
- 날씨/권한 이슈 대응 대체 퀘스트 슬롯(`status=alternative`) 정의
- seed 기반 재현 가능한 생성 예시 포함

## 4. 테스트
1. `swift scripts/quest_stage1_policy_unit_check.swift`
2. `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## 5. 수용 기준 대응
- 활동량 상/중/하 난이도 편차: 버킷 보정 및 clamp 규칙으로 충족
- 동일 타입 반복 출현률 제한: 최근 슬롯 상한/당일 중복 금지로 충족
- 문서만으로 재현 가능: 입력/seed/출력 예시로 충족
