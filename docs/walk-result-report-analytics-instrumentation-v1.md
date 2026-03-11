# 산책 결과 설명 리포트 analytics 계측 v1

- 관련 이슈: `#721`
- 범위: 지도 저장 직후 카드, 저장된 산책 상세 결과 리포트
- 비범위: 외부 analytics vendor 교체, 대규모 UI 재설계

## 목적
- 사용자가 결과 리포트를 어디서 처음 보았는지 기록한다.
- 어떤 상태의 리포트에서 상세/문의 전환이 일어나는지 분석 가능하게 만든다.
- 제외 사유와 연결 상태가 실제 사용자 행동과 어떤 상관이 있는지 추적한다.

## Surface
- `map_saved_card`: 산책 저장 직후 지도 상단 후속 카드
- `walklist_detail`: 저장된 산책 상세 화면 안 결과 리포트 섹션

## 이벤트
- `walk_outcome_report_presented`
  - 리포트 surface가 처음 노출될 때 1회 기록
- `walk_outcome_report_dismissed`
  - 저장 직후 카드의 닫기 액션에서 기록
- `walk_outcome_report_history_opened`
  - 저장 직후 카드에서 산책 목록으로 이동할 때 기록
- `walk_outcome_report_detail_opened`
  - 저장 직후 카드에서 방금 저장한 상세 리포트로 바로 이동할 때 기록
- `walk_outcome_report_disclosure_toggled`
  - 저장된 산책 상세 결과 리포트에서 `제외 이유 / 이어지는 흐름 / 계산 근거` disclosure가 바뀔 때 기록
- `walk_outcome_report_inquiry_opened`
  - 저장된 산책 상세 결과 리포트에서 문의 CTA를 눌러 메일 앱 또는 fallback URL을 여는 데 성공했을 때 기록

## 공통 payload
- `surface`
- `summary_state`
- `applied_point_count`
- `applied_point_bucket`
- `excluded_point_count`
- `excluded_ratio_bucket`
- `top_exclusion_reasons`
- `primary_exclusion_reason`
- `record_connection_status`
- `territory_connection_status`
- `season_connection_status`
- `quest_connection_status`
- `connection_state_key`
- `calculation_source_version`

## 이벤트별 추가 payload
- `walk_outcome_report_dismissed`
  - `dismissal_source`
- `walk_outcome_report_disclosure_toggled`
  - `section`
  - `is_expanded`
- `walk_outcome_report_inquiry_opened`
  - `channel`

## 분석 기준
- `summary_state`
  - `lowApplied`
  - `normalApplied`
  - `policyDominant`
- `top_exclusion_reasons`
  - 최대 3개 reason id를 순서대로 전달
- `connection_state_key`
  - `record/territory/season/quest` 상태를 하나의 문자열 키로 직렬화한 값

## 구현 규칙
- 상태 판단과 bucket 계산은 `WalkOutcomeExplanationDTO.analyticsContext`에서 공통으로 재사용한다.
- 지도 저장 직후 카드와 저장된 산책 상세는 같은 analytics context를 사용한다.
- 계측 payload 구성은 view가 아니라 `WalkOutcomeReportInteractionService`가 담당한다.
- 문의 메일 본문에도 같은 공통 축을 넣어 운영 대응 시 metric과 사용자의 설명을 교차 확인할 수 있게 한다.

## 회귀 고정점
- 접근성 식별자
  - `map.walk.savedOutcome.openDetail`
  - `walklist.detail.outcomeReport.inquiry`
- 기능 회귀 UI
  - `FeatureRegressionUITests/testFeatureRegression_MapSavedOutcomeCardOpensImmediateDetailReport`
  - `FeatureRegressionUITests/testFeatureRegression_WalkListDetailOutcomeReportExplainsAppliedExcludedAndConnections`
- 정적 체크
  - `swift scripts/walk_result_report_analytics_unit_check.swift`
