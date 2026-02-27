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
