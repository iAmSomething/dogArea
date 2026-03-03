# Cycle 205 - Quest Stage2 진행/클레임 백엔드 엔진 (2026-03-03)

## 1) 이슈
- 대상: #128 `[Task][Quest][Stage 2] 퀘스트 진행 엔진/클레임 백엔드 구현`

## 2) 구현 범위
### A. Supabase 마이그레이션
- 신규: `supabase/migrations/20260303120000_quest_stage2_progress_claim_engine.sql`

포함 내용:
1. 퀘스트 핵심 스키마
- `quest_templates`
- `quest_instances`
- `quest_progress`
- `quest_claims`
- `quest_claim_audit_logs`(감사 로그)

2. 서버 RPC
- `rpc_issue_quest_instances`
- `rpc_apply_quest_progress_event`
- `rpc_claim_quest_reward`
- `rpc_transition_quest_status`

3. 안정성 규칙
- 진행도 멱등 키: `(quest_instance_id, event_id)`
- 클레임 중복 방지: `quest_claims.quest_instance_id unique`
- reroll 1일 1회 제한: `quest_claim_audit_logs` 기준 서버 강제

### B. Supabase Functions
1. 신규 edge function
- `supabase/functions/quest-engine/index.ts`
- 액션: `issue_quests`, `ingest_walk_event`, `claim_reward`, `transition_status`, `list_active`

2. 기존 파이프라인 연계
- `supabase/functions/sync-walk/index.ts`
- `points` stage에서 활성 퀘스트에 `rpc_apply_quest_progress_event` 호출
- 응답에 `quest_progress_summary` 추가

### C. 문서/체크
- 신규 문서: `docs/quest-stage2-progress-claim-engine-v1.md`
- 운영 검증 섹션 추가: `docs/supabase-migration.md` (5.14)
- 신규 체크: `scripts/quest_stage2_engine_unit_check.swift`
- 체크 파이프라인 연결: `scripts/ios_pr_check.sh`
- README 링크 추가

## 3) 요구사항 매핑
1. 스키마 설계
- 4개 핵심 테이블(`quest_templates`, `quest_instances`, `quest_progress`, `quest_claims`) 추가로 충족

2. 산책 이벤트 기반 진행도 업데이트
- `sync-walk` points stage에서 quest RPC 연계로 충족

3. 완료 판정/보상 클레임 API
- `rpc_apply_quest_progress_event` + `rpc_claim_quest_reward`로 충족

4. reroll/만료/대체퀘스트 상태 전이
- `rpc_transition_quest_status(expire|reroll|replace)`로 충족

5. 중복 클레임 방지/감사 로그
- `quest_claims` 유니크 + `quest_claim_audit_logs`로 충족

## 4) 테스트
1. 단일 체크
- `swift scripts/quest_stage2_engine_unit_check.swift` -> PASS

2. PR 체크
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS
- `bash scripts/ios_pr_check.sh` -> PASS

## 5) 후속
- 배포 시 `supabase db push --linked`로 마이그레이션 적용 후 SQL 시나리오(중복 이벤트/클레임 경쟁/상태 전이) 실측 검증 필요.
