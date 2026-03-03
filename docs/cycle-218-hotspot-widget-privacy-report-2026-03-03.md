# Cycle #218 익명 핫스팟 위젯 프라이버시 리포트 (2026-03-03)

- 이슈: #218 `[Task][Widget][P1] 익명 핫스팟 위젯(프라이버시 가드 반영)`
- 브랜치: `codex/issue-218-anon-hotspot-widget`
- 목적: 위젯 노출을 단계 중심으로 고정하고, 정책 매핑표를 문서/정적체크로 관리한다.

## 1. 변경 요약

1. 위젯 UI에서 단계별 수치(숫자 카운트) 노출 제거
2. 단계 배지 + 분포 요약 문구 기반 표시로 전환
3. `privacy_mode` + `suppression_reason` 정책 매핑 문서 추가
4. 정적 체크 스크립트에 정책 문서/위젯 노출 규칙 검증 추가

## 2. 파일 변경

- `dogAreaWidgetExtension/WalkControlWidget.swift`
  - `cellMetric` 제거, `stageChip` 기반 렌더링으로 전환
  - `signalDistributionSummary`, `dominantSignalLevel` 추가
  - 소형/중형 카드에서 숫자 카운트 대신 단계 요약 문구 노출
- `docs/hotspot-widget-privacy-mapping-v1.md`
  - `privacy_mode`/`suppression_reason` 매핑표 신규 작성
  - guest/k-anon/sensitive-mask/delay 정책 명시
- `scripts/hotspot_widget_privacy_unit_check.swift`
  - 위젯 숫자 카운트 미노출 검증 추가
  - 정책 문서 존재/핵심 매핑 행 검증 추가
- `README.md`
  - 신규 정책 문서 링크 추가

## 3. 수용 기준 매핑

1. 좌표/정밀 카운트 미노출: 위젯 UI에서 숫자 카운트 텍스트 제거로 충족
2. `k_anon`/`sensitive_mask`/`delay` 카피 노출: 기존 정책 문구 유지 + 정적체크 보강
3. 비회원 제한 카드: guest 카드 카피로 기능 소개형 제한 노출 유지
4. 앱/위젯 정책 정합: 정책 매핑표 문서로 원문 키 기준 분기 고정

## 4. 검증

1. `swift scripts/hotspot_widget_privacy_unit_check.swift`
2. `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
