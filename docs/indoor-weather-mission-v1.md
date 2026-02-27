# Indoor Weather Replacement Mission v1 (Issue #152)

## 1. 목표
- 악천후 시 실외 중심 목표를 실내 대체 미션으로 자동 치환한다.
- 단순 1회 탭 완료를 막기 위해 미션별 최소 행동량 기준을 강제한다.

## 2. 실내 미션 카탈로그
- `recordCleanup`: 기록 정리/사진 정리
- `petCareCheck`: 물/브러싱/컨디션 체크
- `trainingCheck`: 기다려/손/집중 훈련 체크

각 템플릿은 다음 속성을 가진다.
- `minimumActionCount`
- `baseRewardPoint`
- `streakEligible`

## 3. 악천후 단계별 치환 규칙
- 위험도: `clear`, `caution`, `bad`, `severe`
- 치환 수량
  - `clear`: 0
  - `caution`: 1
  - `bad`: 2
  - `severe`: 3
- 보상 감액 계수
  - `caution`: 0.92
  - `bad`: 0.88
  - `severe`: 0.84

## 4. 완료 판정
- `actionCount >= minimumActionCount` 일 때만 완료 확정
- 미달 시 `completion rejected` 처리하고 사용자에게 부족 행동량 안내

## 5. 반복 노출 제한
- 최근 2일에 노출된 미션 템플릿은 우선 제외
- 후보 부족 시에만 fallback으로 전체 템플릿에서 채움

## 6. 관측 지표
- `indoor_mission_replacement_applied`
- `indoor_mission_action_logged`
- `indoor_mission_completed`
- `indoor_mission_completion_rejected`

## 7. 체감 날씨 피드백 루프 연계 (#151)
- 홈 카드에서 `체감 날씨 다름` 1탭 액션 제공
- 반영 범위는 당일 위험도에 한정, 주간 2회 제한 적용
- 피드백으로 위험도를 완전 해제(`clear`)하지 않음
- 상세 명세: `docs/weather-feedback-loop-v1.md`

## 8. 실패 완충 연장 슬롯 (#148)
- 자동 연장 슬롯은 하루 1개 미션에만 적용한다.
- 연장 보상은 기본 보상의 `70%`로 감액한다.
- 연장 미션은 시즌 점수/연속 보상 집계에서 제외한다.
- 연장 슬롯은 연속 2일 이상 자동 적용하지 않는다.
- 연장 미션을 당일 미완료하면 추가 구제 없이 소멸한다.
