# Quest Failure Buffer v1 (Issue #148)

## 1. 목표
- 데일리 미션을 하루 놓쳤을 때 즉시 이탈하지 않도록 자동 연장 슬롯을 제공한다.
- 완충 장치를 제공하되 보상 밸런스와 남용 방지 정책을 유지한다.

## 2. 정책
- 자동 연장 슬롯은 하루에 최대 1개 미션에만 적용한다.
- 연장 보상은 기본 보상의 `70%`로 지급한다.
- 연장 슬롯은 연속 2일 이상 자동 적용하지 않는다.
- 연장 미션을 또 미완료하면 추가 구제 없이 소멸한다.
- 연장 미션은 시즌 점수/연속 보상(streak) 대상에서 제외한다.

## 3. 상태 정의
- `none`: 오늘 연장 슬롯 없음
- `active`: 전일 미션 1개가 오늘로 연장됨
- `consumed`: 연장 미션 완료 처리됨
- `expired`: 전일 연장 미션 미완료로 소멸됨
- `cooldown`: 연속 연장 방지 규칙으로 오늘 자동 연장 차단됨

## 4. 데이터 규칙
- 액션/완료 카운트는 `dayKey|missionId` 키를 사용한다.
- 연장 미션은 원본 `missionId`와 `sourceDayKey`를 보존해 전일 진행량을 이어받는다.
- 연장 슬롯 ledger는 최근 21일만 유지한다.

## 5. UI 규칙
- 홈 미션 카드에 연장 상태 메시지를 노출한다.
- 연장 미션 행에 `연장 슬롯` 배지와 `보상 70%` 안내를 노출한다.
- 소멸/쿨다운 상태는 미션이 없어도 카드에서 확인 가능해야 한다.

## 6. 메트릭
- `indoor_mission_extension_applied`
- `indoor_mission_extension_consumed`
- `indoor_mission_extension_expired`
- `indoor_mission_extension_blocked`
