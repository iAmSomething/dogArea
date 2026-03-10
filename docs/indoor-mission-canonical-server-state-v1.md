# Indoor Mission Canonical Server State v1 (Issue #474)

## 1. 목표
- 실내 미션 보드, 완료 판정, 보상 수령, 쉬운 날 모드의 canonical source를 서버로 일원화한다.
- 홈 미션 카드 UX와 사용 흐름은 최대한 유지하고, 클라이언트는 표시와 짧은 optimistic state만 담당한다.

## 2. Canonical Ownership
서버가 최종 source of truth를 가진다.

- 오늘 발급된 실내 미션 목록
- 미션 제목/설명/최소 행동 수/보상 포인트
- 연장 미션 할당 여부와 감액 배율
- 쉬운 날 모드 적용 여부와 감액 상태
- 행동 누적 수
- 완료 가능 여부(`claimable`)
- 보상 지급 가능 여부(`rewardEligible`)
- claim 완료 여부

클라이언트는 위 값을 영구 확정하지 않는다.

- member 세션은 최근 canonical summary cache를 먼저 읽고, background refresh로 최신 상태를 다시 가져온다.
- guest 또는 cloudSync 불가 세션은 기존 로컬 fallback 보드를 임시 표시용으로만 사용한다.

## 3. 서버 계약
### 3-1. Summary RPC
- 함수: `rpc_get_indoor_mission_summary(payload jsonb)`
- 입력:
  - `in_pet_context_id`
  - `in_pet_name`
  - `in_age_years`
  - `in_recent_daily_minutes`
  - `in_average_weekly_walk_count`
  - `in_base_risk_level`
  - `in_day_key`
  - `in_now_ts`
- 출력:
  - `owner_user_id`
  - `pet_context_id`
  - `day_key`
  - `base_risk_level`
  - `effective_risk_level`
  - `extension_state`
  - `extension_message`
  - 난이도/easy-day/history 필드
  - `missions`
  - `refreshed_at`

### 3-2. Action RPC
- 함수: `rpc_record_indoor_mission_action(payload jsonb)`
- 입력:
  - `in_mission_instance_id`
  - `in_request_id`
  - `in_event_id`
  - `in_now_ts`
- 출력:
  - `mission_instance_id`
  - `template_id`
  - `event_id`
  - `idempotent`
  - `action_count`
  - `minimum_action_count`
  - `claimable`
  - `status`
  - `refreshed_at`

### 3-3. Claim RPC
- 함수: `rpc_claim_indoor_mission_reward(payload jsonb)`
- 입력:
  - `in_mission_instance_id`
  - `in_day_key`
  - `in_pet_context_id`
  - `in_request_id`
  - `in_now_ts`
- 출력:
  - `mission_instance_id`
  - `template_id`
  - `claim_status`
  - `already_claimed`
  - `reward_points`
  - `claimed_at`
  - `refreshed_at`

### 3-4. Easy Day RPC
- 함수: `rpc_activate_indoor_easy_day(payload jsonb)`
- 입력:
  - summary RPC와 동일한 반려견/날씨 payload
- 출력:
  - `outcome`
  - `pet_context_id`
  - `already_applied`
  - `refreshed_at`

### 3-5. Sync-Walk 연계
- `sync-walk` points stage는 `indoor_mission_canonical_summary`를 함께 반환한다.
- iOS는 member 세션일 때만 이 summary를 `IndoorMissionCanonicalSummaryStore`에 저장한다.
- 홈은 그 cache를 먼저 읽고, 이후 summary RPC를 다시 호출해 최신 상태로 덮어쓴다.

## 4. 클라이언트 Consume 정책
### member + cloudSync 가능
- 홈 진입 시 `IndoorMissionCanonicalSummaryStore`에서 현재 `dayKey + petContextId` 기준 cache를 먼저 읽는다.
- cache hit면 홈 미션 카드를 먼저 그린다.
- 이후 `rpc_get_indoor_mission_summary`를 비동기로 다시 호출해 최신 상태를 반영한다.
- `action +1`은 로컬에서 짧은 optimistic progress를 보여줄 수 있지만, 최종 actionCount/claimable은 서버 응답으로 덮어쓴다.
- 보상 수령은 `rpc_claim_indoor_mission_reward`만 사용한다.
- 쉬운 날 모드는 `rpc_activate_indoor_easy_day`만 사용한다.

### guest 또는 cloudSync 불가
- 서버 canonical summary를 만들지 않는다.
- 기존 `IndoorMissionStore` 로컬 보드를 read-only fallback으로만 사용한다.
- guest fallback은 미션 발급/완료/보상의 장기 canonical source가 아니다.

## 5. Fallback 정책
- summary fetch 실패:
  - 홈은 현재 로컬 fallback 보드 또는 마지막 member cache를 유지한다.
- cache 만료:
  - `30분`을 초과한 cache는 fresh canonical summary로 사용하지 않는다.
- action/claim/easy-day RPC 실패:
  - 로컬 completed/claimed를 영구 확정하지 않는다.
  - 상태 메시지와 재시도 안내만 노출하고, 다음 refresh에서 다시 동기화한다.
- 서버 복구:
  - 다음 홈 refresh 또는 다음 `sync-walk` points stage에서 최신 summary로 수렴한다.

## 6. 멱등성과 멀티디바이스 규칙
- `action +1`은 `in_request_id` / `in_event_id` 기준으로 멱등 처리한다.
- reward claim은 `in_request_id` 기준으로 멱등 처리한다.
- 동일 계정 멀티디바이스에서도 실내 미션 상태는 서버 row/ledger 하나로 수렴한다.
- 클라이언트 cache는 `ownerUserId + dayKey + petContextId` 조합으로 바인딩되고, 다른 사용자 snapshot은 무시한다.

## 7. QA 시나리오
1. member 기기 A에서 action +1 후 홈 카드 progress가 서버 값으로 다시 맞춰지는지 확인
2. 같은 계정 기기 B에서 홈 진입 시 같은 실내 미션/claimable 상태가 보이는지 확인
3. reward claim 후 앱 재설치/재로그인 뒤에도 claimed 상태가 유지되는지 확인
4. 쉬운 날 모드 적용 후 홈 카드 보상/문구가 서버 기준으로 유지되는지 확인
5. `sync-walk` points stage 직후 `indoor_mission_canonical_summary` cache가 저장되는지 확인
6. guest 세션에서는 서버 canonical cache를 읽지 않고 로컬 fallback만 쓰는지 확인

## 8. 관련 문서
- `docs/weather-canonical-server-state-v1.md`
- `docs/season-canonical-server-state-v1.md`
- `docs/home-quest-help-layer-v1.md`
- `docs/home-quest-tracking-mode-guideline-v1.md`
