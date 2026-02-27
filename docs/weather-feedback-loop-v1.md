# Weather Feedback Loop v1 (Issue #151)

## 1. 목표
- 날씨 API 판정과 체감 불일치 시 사용자가 1탭으로 당일 판정을 보정할 수 있게 한다.
- 남용을 막기 위해 주간 반영 횟수를 제한한다.

## 2. UX 계약
- CTA: `체감 날씨 다름` 버튼(홈 실내 대체 미션 카드 내)
- 즉시 결과 표시:
  - 판정 조정 시: `원래 위험도 -> 조정 위험도`
  - 미조정 시: 안전 기준으로 유지 안내
- 잔여 횟수 표시: `주간 남은 반영 N/2`

## 3. 반영 규칙
- 반영 범위: `당일` 판정에만 적용
- 주간 제한: `2회`
- 위험도 조정:
  - `severe -> bad`
  - `bad -> caution`
  - `caution -> caution` (완전 해제 금지)
- 피드백만으로 `clear`로 완전 해제하지 않음

## 4. 저장 키(클라이언트)
- `weather.feedback.timestamps.v1`: 주간 제한 계산용 timestamp 배열
- `weather.feedback.dailyAdjustment.v1`: 일자별 위험도 보정 step

## 5. 관측 지표
- `weather_feedback_submitted`
- `weather_feedback_rate_limited`
- `weather_risk_reevaluated`

대시보드 뷰:
- `public.view_weather_feedback_kpis_7d`
  - `submitted_count`, `rate_limited_count`, `changed_count`, `unchanged_count`
  - `changed_ratio`, `rate_limited_ratio`

## 6. 검증 체크리스트
- [ ] 피드백 1회 입력 시 당일 위험도 재평가 반영
- [ ] 주간 3회 입력 시 3회차가 rate-limit 처리
- [ ] 피드백으로 위험도가 `clear`로 완전 해제되지 않음
- [ ] `view_weather_feedback_kpis_7d`에서 일자별 지표 조회 가능
