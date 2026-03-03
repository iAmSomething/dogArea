# Quest Stage2 Progress/Claim Engine v1

## 1. 목적
Stage1 정책(#127)을 서버 런타임으로 연결해 퀘스트 인스턴스 발급/진행도 반영/보상 클레임을 일관된 계약으로 제공한다.

연결 이슈:
- Stage2: #128
- 선행: #127, #170

## 2. 스키마
1. `quest_templates`
- 퀘스트 템플릿 카탈로그
- `quest_scope`, `quest_type`, `base_target_value`, 보상 스냅샷 소스

2. `quest_instances`
- 사용자별 발급 인스턴스
- 생성 시 `target_value_snapshot`/보상 스냅샷 고정
- 상태: `generated -> active -> completed -> claimed | expired | rerolled | alternative`

3. `quest_progress`
- 이벤트 소싱 기반 진행도 증분 로그
- 멱등 키: `unique (quest_instance_id, event_id)`

4. `quest_claims`
- 보상 수령 원장
- 중복 클레임 방지: `unique (quest_instance_id)`

5. `quest_claim_audit_logs`
- 클레임/상태전이 감사 로그
- `claim_confirmed`, `duplicate_claim_blocked`, `claim_rejected`, `reroll_transition`, `replace_transition`, `expire_transition`

## 3. RPC 계약
1. `rpc_issue_quest_instances`
- 일/주 퀘스트 인스턴스 발급
- `cycle_key` 단위 멱등 upsert

2. `rpc_apply_quest_progress_event`
- 이벤트 기반 진행도 반영
- 동일 `event_id` 재처리 시 진행도 증가 0건 보장

3. `rpc_claim_quest_reward`
- 완료 인스턴스 서버 검증 후 클레임 확정
- 동시 요청 경쟁에서도 중복 수령 0건 (`quest_claims` 유니크 + row lock)

4. `rpc_transition_quest_status`
- `expire`, `reroll`, `replace` 상태 전이
- reroll 1일 1회 제한은 감사 로그 기반으로 서버 강제

## 4. Edge Function
- `supabase/functions/quest-engine`
- 액션:
  - `issue_quests`
  - `ingest_walk_event`
  - `claim_reward`
  - `transition_status`
  - `list_active`

## 5. Walk 이벤트 파이프라인 연계
- `supabase/functions/sync-walk/index.ts` points stage에서 활성 퀘스트를 조회해 `rpc_apply_quest_progress_event` 호출
- 응답에 `quest_progress_summary`를 추가해 서버 확정 진행도와 앱 UI 동기화

## 6. 수용 기준 매핑
1. 동일 이벤트 재처리 시 진행도 중복 증가 0건
- `quest_progress`의 `(quest_instance_id, event_id)` 유니크로 보장

2. 동시 클레임 경쟁 조건에서도 중복 수령 0건
- `quest_claims.quest_instance_id` 유니크 + `rpc_claim_quest_reward` row lock/감사 로그로 보장

3. 만료/reroll/대체 상태 전이 명세 일치
- `rpc_transition_quest_status`에서 `expire|reroll|replace` 전이를 단일 경로로 강제
