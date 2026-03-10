# Issues #465 #467 Closure Evidence v1

## 대상
- issues: `#465`, `#467`
- theme: `산책 중 Quest Companion HUD`, `마일스톤 토스트`, `확장 체크리스트`, `HUD 최소 정보셋`

## 구현 근거
### #465 산책 중 퀘스트 Companion HUD·마일스톤 토스트·확장 체크리스트 설계
- `#465`에서 요구한 기본 패턴은 저장소 문서 기준으로 `HUD + milestone toast + expandable checklist`로 정의됐다.
- critical banner와 quest feedback의 우선순위는 별도 policy 문서에서 분리되어 있다.
- overlay 경쟁 시 접힘 규칙은 `#468`의 overlay priority matrix와 함께 해석된다.
- 근거 문서:
  - `docs/map-quest-feedback-hud-v1.md`
  - `docs/map-quest-overlay-priority-matrix-v1.md`

### #467 산책 중 Companion HUD 최소 정보셋·축약 규칙 정의
- `#467`에서 요구한 collapsed / expanded 정보셋, 줄 수 제한, empty state, 다중 미션 규칙은 최소 정보셋 정책 문서로 고정됐다.
- collapsed HUD는 `2줄 + 상태 배지 1개` 기준으로 제한되고, expanded에서만 자세한 정보를 허용한다.
- 근거 문서:
  - `docs/map-quest-hud-minimum-info-set-v1.md`

## DoD 판정
### 1. #465 기본 피드백 계층이 모달 Alert가 아니라 비차단 HUD 중심으로 정의되어 있다
- 기본값은 상시 HUD, milestone toast, expandable checklist의 3계층이다.
- 진행 피드백은 모달 Alert 기본 사용을 금지하고, 예외 상황에만 Alert를 허용한다.
- 판정: `PASS`

### 2. #465 critical banner와 quest feedback의 우선순위가 정의되어 있다
- quest feedback policy와 overlay priority matrix가 함께 존재한다.
- 상단 overlay 경쟁 시 quest feedback이 어떻게 접히고 강등되는지 문서 기준이 있다.
- 판정: `PASS`

### 3. #467 collapsed / expanded 최소 정보셋과 축약 규칙이 명확하다
- collapsed HUD는 대표 미션명, 한 줄 진행 요약, 상태 배지 수준으로 제한된다.
- 다중 미션은 `대표 1개 + 추가 n개`, 완료/보상 가능/empty state 규칙도 문서화됐다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/map_quest_feedback_policy_unit_check.swift`
  - `swift scripts/map_quest_hud_minimum_info_unit_check.swift`
  - `swift scripts/map_quest_overlay_priority_unit_check.swift`
  - `swift scripts/issues_465_467_closure_evidence_unit_check.swift`
- PR 체크
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#465`, `#467`은 둘 다 `지도 퀘스트 HUD 정책/정의` 범주 이슈로, 저장소 기준 구현 근거와 게이트가 존재한다.
- 이 문서를 기준으로 두 이슈를 함께 닫아도 된다.
