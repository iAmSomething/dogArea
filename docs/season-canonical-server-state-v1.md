# Season Canonical Server State v1 (Issue #473)

## 1. 목표
- 시즌 점수, 랭크, 진행률, 보상 상태의 canonical source를 서버로 일원화한다.
- 홈 시즌 카드, 시즌 결과 오버레이, 랭크업 모션의 체감 동작은 최대한 유지한다.
- 클라이언트의 `SeasonMotionStore`는 표시 보조와 짧은 optimistic window 용도로만 남긴다.

## 2. Canonical Ownership
서버가 최종 source of truth를 가진다.

- `weekKey`
- `score`
- `targetScore`
- `progress`
- `rankTier`
- `todayScoreDelta`
- `contributionCount`
- `weatherShieldApplyCount`
- 시즌 완료 상태
- 시즌 보상 수령 상태

클라이언트는 위 값을 영구 확정하지 않는다.

- member 세션은 서버 summary cache를 먼저 읽고, background refresh로 최신 summary를 다시 가져온다.
- guest 세션은 기존 `SeasonMotionStore` 값을 read-only fallback으로만 사용한다.

## 3. 서버 계약
### 3-1. Summary RPC
- 함수: `rpc_get_owner_season_summary(payload jsonb)`
- 입력:
  - `in_now_ts`
  - `in_season_id`
  - `in_week_key`
- 출력:
  - `current_season_id`
  - `current_season_key`
  - `current_week_key`
  - `current_status`
  - `current_score`
  - `current_target_score`
  - `current_progress`
  - `current_rank_tier`
  - `current_today_score_delta`
  - `current_contribution_count`
  - `current_weather_shield_apply_count`
  - `current_score_updated_at`
  - `current_last_contribution_at`
  - 최근 완료 시즌과 보상 상태 필드
  - `refreshed_at`

### 3-2. Reward Claim RPC
- 함수: `rpc_claim_season_reward(payload jsonb)`
- 입력:
  - `in_season_id`
  - `in_week_key`
  - `in_request_id`
  - `in_now_ts`
  - `in_source`
- 출력:
  - `season_id`
  - `week_key`
  - `reward_code`
  - `claim_status`
  - `already_claimed`
  - `claimed_at`
  - `request_id`
  - `refreshed_at`

### 3-3. Sync-Walk 연계
- `sync-walk` points stage는 `season_canonical_summary`를 함께 반환한다.
- iOS는 member 세션일 때만 이 summary를 `SeasonCanonicalSummaryStore`에 저장한다.
- 홈은 그 cache를 먼저 읽고, 이후 `rpc_get_owner_season_summary`로 background refresh를 수행한다.

## 4. 클라이언트 consume 정책
### member + cloudSync 가능
- 홈 진입 시 `SeasonCanonicalSummaryStore`에서 `30분` 이내 cache를 먼저 읽는다.
- cache hit면 시즌 카드와 결과 오버레이를 먼저 그린다.
- 이후 `rpc_get_owner_season_summary`를 비동기로 다시 호출해 최신 상태로 덮어쓴다.
- 보상 수령은 `rpc_claim_season_reward`만 사용한다.
- claim 후에는 cache를 갱신하고 summary를 다시 fetch해 최종 상태를 반영한다.

### guest 또는 cloudSync 불가
- 서버 canonical summary를 만들지 않는다.
- 기존 `SeasonMotionStore` 값을 읽기 전용 fallback으로만 표시한다.
- guest fallback은 점수/랭크/보상 상태의 장기 canonical source가 아니다.

## 5. Fallback 정책
- summary fetch 실패:
  - 홈은 현재 `SeasonMotionStore` fallback 값을 유지한다.
  - member 세션에서 최근 cache가 있으면 그 cache를 우선 사용한다.
- cache 만료:
  - `30분`을 초과한 summary cache는 canonical summary로 사용하지 않는다.
- reward claim 실패:
  - 로컬 `claimed`를 확정하지 않는다.
  - 서버 재확인 안내만 노출하고 다음 refresh에서 다시 동기화한다.
- 비로그인/오프라인:
  - 서버 canonical 확정 동작 없이 read-only fallback만 유지한다.

## 6. 멱등성과 멀티디바이스 규칙
- 보상 수령은 `in_request_id` 기준으로 멱등 처리한다.
- `season_rewards(owner_user_id, claim_request_id)` unique index로 중복 claim을 막는다.
- 동일 계정이 여러 기기에서 눌러도 서버 reward ledger 하나만 canonical source가 된다.
- 클라이언트 cache는 사용자 ID로 바인딩되고, 다른 사용자 snapshot은 무시한다.

## 7. Parity / Diff 관측성
- 홈은 로컬 fallback과 서버 canonical summary가 다를 때 metric을 남긴다.
- metric:
  - `season_canonical_refreshed`
  - `season_canonical_mismatch_detected`
  - `season_reward_claim_succeeded`
  - `season_reward_claim_failed`
- debug 로그:
  - week mismatch
  - score / rank mismatch
  - reward claim failure

## 8. QA 시나리오
1. member 기기 A에서 `sync-walk` 후 홈 시즌 카드가 서버 summary로 갱신되는지 확인
2. 같은 계정 기기 B에서 홈 진입 시 동일 점수/랭크/보상 상태가 보이는지 확인
3. 시즌 결과 오버레이에서 보상 수령을 여러 번 눌러도 중복 claimed가 생기지 않는지 확인
4. summary RPC 실패 시 홈이 로컬 fallback으로 유지되는지 확인
5. guest 세션에서는 서버 summary cache를 읽지 않고 `SeasonMotionStore` fallback만 쓰는지 확인

## 9. 관련 문서
- `docs/season-stage2-pipeline-v1.md`
- `docs/season-motion-pack-v1.md`
- `docs/backend-request-correlation-idempotency-policy-v1.md`
