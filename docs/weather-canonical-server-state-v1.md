# Weather Canonical Server State v1 (Issue #475)

## 1. 목표
- 날씨 치환, shield, 체감 피드백 quota의 canonical state를 서버로 일원화한다.
- 홈 날씨 카드와 실내 미션 UX는 최대한 유지하고, 앱은 결과 표시와 사용자 입력 수집에 집중한다.

## 2. Canonical Ownership
서버가 최종 source of truth를 가진다.

- 최종 위험도(`clear/caution/bad/severe`)
- replacement 적용 여부
- replacement 이유 문구 원천 데이터
- 일일 replacement 사용량 / 한도
- 주간 shield 사용량 / 한도
- shield 마지막 적용 시각
- 주간 체감 피드백 사용량 / 한도 / 잔여 횟수

클라이언트는 위 상태를 영구 확정하지 않는다.

- 로컬 저장소는 member 세션용 최근 summary cache만 유지한다.
- guest 세션은 기존 로컬 fallback을 임시 표시용으로만 사용한다.

## 3. 서버 계약
### 3-1. Summary RPC
- 함수: `rpc_get_weather_replacement_summary(payload jsonb)`
- 입력:
  - `in_base_risk_level`
  - `in_now_ts`
- 출력:
  - `base_risk_level`
  - `effective_risk_level`
  - `applied`
  - `blocked_reason`
  - `replacement_reason`
  - `replacement_count_today`
  - `daily_replacement_limit`
  - `shield_used_this_week`
  - `weekly_shield_limit`
  - `shield_apply_count_today`
  - `shield_last_applied_at`
  - `feedback_used_this_week`
  - `weekly_feedback_limit`
  - `feedback_remaining_count`
  - `refreshed_at`

### 3-2. Feedback RPC
- 함수: `rpc_submit_weather_feedback(payload jsonb)`
- 입력:
  - `in_base_risk_level`
  - `in_request_id`
  - `in_now_ts`
- 출력:
  - `accepted`
  - `message`
  - `original_risk_level`
  - `adjusted_risk_level`
  - summary RPC와 동일한 canonical summary 필드

### 3-3. Sync-Walk 연계
- `sync-walk` points stage는 `weather_replacement_summary`를 함께 반환한다.
- 홈은 이 summary를 우선 cache로 저장하고, 이후 background refresh로 최신 summary를 다시 가져온다.

## 4. 클라이언트 Consume 정책
### member + cloudSync 가능
- 홈 진입 시 `WeatherReplacementSummaryStore`에서 `30분` 이내 summary cache를 먼저 사용한다.
- cache miss 또는 stale이면 UI는 기존 snapshot 기반 상태로 먼저 그린다.
- 이후 `rpc_get_weather_replacement_summary`를 비동기로 다시 호출해 최신 상태로 동기화한다.
- 사용자가 `체감 날씨 다름`을 누르면 `rpc_submit_weather_feedback`로 서버에 제출한다.
- feedback 결과는 summary cache를 갱신하고, 홈 카드/실내 미션 상태를 즉시 다시 계산한다.

### guest 또는 cloudSync 불가
- 서버 canonical summary를 만들지 않는다.
- 기존 `IndoorMissionStore`의 로컬 fallback 경로를 임시 표시용으로만 사용한다.
- 이 경로는 quota/ledger의 장기 canonical source가 아니다.

## 5. Fallback 정책
- summary fetch 실패:
  - 홈은 현재 weather snapshot 기반 기본 위험도 상태를 유지한다.
  - replacement/shield/feedback 카운터는 마지막 정상 member cache가 있으면 그 값을 보조적으로 사용한다.
- cache 만료:
  - `30분`을 초과한 summary cache는 canonical summary로 사용하지 않는다.
- feedback 제출 실패:
  - UI는 기존 상태를 유지하고 재시도 안내만 노출한다.
- 서버 복구:
  - 다음 홈 refresh 또는 다음 `sync-walk` points stage에서 최신 summary로 재동기화한다.

## 6. 멱등성과 멀티디바이스 규칙
- 체감 피드백은 `in_request_id` 기준으로 멱등 처리한다.
- 동일 계정이 여러 기기에서 피드백을 보내도 quota는 서버 ledger 하나로 계산한다.
- shield 사용량과 마지막 적용 시각도 서버 ledger 기준으로만 집계한다.
- 클라이언트는 사용자별 cache만 읽고, 다른 사용자 summary는 무시한다.

## 7. QA 시나리오
1. member 기기 A에서 feedback 제출 후 홈 카드 quota 감소 확인
2. 같은 계정 기기 B에서 홈 진입 시 동일 quota가 보이는지 확인
3. `sync-walk` 후 홈 카드의 shield 요약과 서버 summary가 충돌하지 않는지 확인
4. 날씨 API/summary RPC 실패 시 홈이 snapshot 기반 fallback으로 유지되는지 확인
5. guest 세션에서는 서버 summary cache를 읽지 않고 로컬 fallback만 쓰는지 확인

## 8. 관련 문서
- `docs/weather-replacement-shield-engine-v1.md`
- `docs/weather-feedback-loop-v1.md`
- `docs/weather-snapshot-provider-v1.md`
- `docs/weather-ux-fallback-accessibility-v1.md`
