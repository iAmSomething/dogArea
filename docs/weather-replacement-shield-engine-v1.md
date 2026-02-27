# Weather Replacement & Shield Engine v1 (Issue #134)

## 1. 목표
- 악천후 리스크 단계에서 실외 중심 퀘스트를 서버에서 자동 치환한다.
- 스트릭 보호(Weather Shield)를 서버 정책으로 주당 1회 자동 적용한다.
- 치환/보호 이력을 감사 가능하게 저장한다.

## 2. 서버 데이터 모델
1. `weather_replacement_runtime_policies`
- 일일 치환 한도(`daily_replacement_limit`)
- 주간 Shield 한도(`weekly_shield_limit`)
- 정책 활성화(`enabled`)

2. `weather_replacement_mappings`
- 위험 단계(`risk_level`)별 대체 매핑
- `source_quest_type -> replacement_quest_type`
- 사용자 안내용 `reason_template`

3. `weather_replacement_histories`
- 치환 이력/사유/적용 시각
- 원 퀘스트 ID(`source_quest_id`)와 치환 퀘스트 ID(`replacement_quest_id`)를 함께 기록
- `shield_applied`로 보호 적용 여부 기록

4. `weather_shield_ledgers`
- Shield 지급/소진 이력 원장
- 사용자/주차 단위로 적용 횟수 계산

## 3. RPC 계약
함수: `rpc_apply_weather_replacement`

입력:
- `target_user_id`
- `target_walk_session_id`
- `target_risk_level`
- `source_quest_id`
- `replaced_quest_id`
- `now_ts`

출력:
- `applied`
- `shield_applied`
- `blocked_reason`
- `risk_level`
- `replacement_reason`
- `replacement_count_today`
- `daily_replacement_limit`
- `shield_used_this_week`
- `weekly_shield_limit`

## 4. 정책 규칙 v1
- 위험 단계(`caution|bad|severe`)에서만 치환 시도
- 동일 사용자 일일 치환 최대 1회
- Shield 자동 적용은 주당 1회
- 원 퀘스트는 복원하지 않고 이력으로만 보존
- 서버가 최종 확정, 앱은 결과 표시만 수행

## 5. sync-walk 연계
- `sync-walk` points stage에서 시즌 점수 RPC 이후 `rpc_apply_weather_replacement` 호출
- 응답에 `weather_replacement_summary` 포함
- 구버전 클라이언트(리스크 미전송)는 `target_risk_level=clear` 처리로 치환 미적용

## 6. QA 시나리오
1. `bad` 리스크 입력 시 자동 치환 + 이력 기록 확인
2. 같은 날 2회 호출 시 `daily_limit_reached` 차단 확인
3. 같은 주 2회 위험 호출 시 Shield 1회만 적용 확인
4. 치환 이력에 원/치환 퀘스트 ID와 사유가 누락 없이 남는지 확인
