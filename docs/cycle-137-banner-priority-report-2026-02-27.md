# Cycle 137 Report — Map Banner Priority Queue (2026-02-27)

## 1. 대상
- Issue: `#137 [P0][Task] 배너 우선순위 큐 도입`
- Branch: `codex/cycle-137-banner-priority`

## 2. 변경 요약
- `MapView` 상단 배너 표시를 단일 슬롯(`activeBanner`) 구조로 전환.
- 배너 타입/치명도(`P0/P1/P2`)와 노출 정책(`autoDismissAfter`, `suppressFor`) 추가.
- 복구/미종료/동기화/런타임/게스트/워치 배너를 `topBannerView(for:)` 경로로 통합.
- 복구 배너와 상단 배너 동시 중첩 렌더를 제거해 충돌 가능성을 제거.

## 3. 변경 파일
- `dogArea/Views/MapView/MapView.swift`
  - `activeBanner` 상태, 우선순위 계산, dismiss/auto-dismiss 큐 로직 추가
  - 상단 배너 렌더 경로 통합
- `docs/map-banner-priority-queue-v1.md`
  - 배너 우선순위/정책 문서화
- `docs/release-regression-checklist-v1.md`
  - 배너 큐 회귀 항목 추가
- `scripts/banner_priority_queue_unit_check.swift`
  - 구조/정책 정적 검증 스크립트 추가

## 4. 유닛 체크
- `swift scripts/banner_priority_queue_unit_check.swift` -> PASS
- `swift scripts/walk_runtime_guardrails_unit_check.swift` -> PASS
- `swift scripts/recovery_ux_unit_check.swift` -> PASS

## 5. 빌드 확인
- `xcodebuild -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` -> **BLOCKED**
- 사유: 워크트리에 `OpenAIConfiguration.xcconfig`가 없어 base configuration 파일을 열지 못함
## 6. 리스크/후속
- 실제 시각 노출 시간(4s/6s)과 suppression 값은 실기기 QA에서 미세 조정 필요.
- `RecoveryActionBanner` 공용 파일과 `MapView.swift` 내 타입 중복은 별도 구조 정리 이슈에서 제거 권장.
