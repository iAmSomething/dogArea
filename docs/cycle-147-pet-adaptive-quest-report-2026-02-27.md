# Cycle 147 Report — Pet Adaptive Quest Difficulty + Easy Day (2026-02-27)

## 1. 대상
- Issue: `#147 [P1][Task] 반려견 맞춤 퀘스트 난이도 + 쉬운 날 모드`
- Branch: `codex/cycle-147-pet-adaptive-quest`

## 2. 구현 요약
- 선택 반려견 기준 난이도 신호(연령대/활동량/산책 빈도) 도입
- 목표 자동 조정 규칙 구현:
  - 기본 배율 1.0
  - 신호별 가중치 반영
  - 일일 최대 변동폭 제한(±0.15)
- 쉬운 날 모드(일 1회) 추가:
  - 당일 보상 20% 감액
  - 활성화/제한 상태 메시지 노출
- 홈 미션 카드에 조정 설명 + 최근 히스토리(최대 3건) 표시
- 다견가정 반영: 선택 반려견 컨텍스트 변경 시 난이도 즉시 재계산
- 메트릭 이벤트 추가:
  - `indoor_mission_difficulty_adjusted`
  - `indoor_mission_easy_day_activated`
  - `indoor_mission_easy_day_rejected`

## 3. 변경 파일
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/HomeView/HomeView.swift`
- `dogArea/Source/UserdefaultSetting.swift`
- `docs/pet-adaptive-quest-difficulty-v1.md`
- `docs/release-regression-checklist-v1.md`
- `docs/indoor-weather-mission-v1.md`
- `docs/cycle-147-pet-adaptive-quest-report-2026-02-27.md`
- `README.md`
- `scripts/pet_adaptive_quest_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 유닛 체크
- `swift scripts/pet_adaptive_quest_unit_check.swift` -> PASS
- `swift scripts/quest_failure_buffer_unit_check.swift` -> PASS
- `swift scripts/indoor_weather_mission_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 현재 난이도 ledger/easy-day 사용 이력은 클라이언트 저장(UserDefaults) 기반이므로 다기기 동기화 필요 시 서버 정책 저장소로 이관 필요.
- 시즌 점수 서버 집계 시 쉬운 날 감액/난이도 배율을 서버 규칙에 동일 반영하는 후속 작업 필요.
