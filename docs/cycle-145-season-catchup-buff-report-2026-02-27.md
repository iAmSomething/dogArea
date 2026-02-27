# Cycle 145 Report — Season Comeback Catch-up Buff (2026-02-27)

## 1. 대상
- Issue: `#145 [P1][Task] 시즌 복귀자 캐치업 버프(48시간 한정)`
- Branch: `codex/cycle-145-season-catchup-buff`

## 2. 구현 요약
- Supabase에 복귀 버프 정책/지급 원장 테이블 추가
  - `season_catchup_buff_policies`
  - `season_catchup_buff_grants`
- 시즌 점수 RPC(`rpc_score_walk_session_anti_farming`)를 확장
  - 자격: 72시간 비활동
  - 적용: 48시간, 신규 타일 기여 점수 +20%
  - 제한: 주간 1회, 시즌 종료 24시간 전 신규 지급 차단
  - 로깅: grant/차단 이벤트를 감사 로그에 기록
- `sync-walk` points 응답의 캐치업 필드(`catchup_bonus`, `catchup_buff_active`, `catchup_buff_*`)를 iOS에서 파싱
- iOS 로컬 스냅샷(`SeasonCatchupBuffSnapshot`) 저장 및 Home 상태 배너 연동
  - 적용 중/차단/만료 상태 표시
- 운영 문서/릴리즈 체크리스트/자동 체크 스크립트 업데이트

## 3. 변경 파일
- `supabase/migrations/20260227223000_season_comeback_catchup_buff.sql`
- `supabase/functions/sync-walk/index.ts`
- `dogArea/Source/UserdefaultSetting.swift`
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/HomeView/HomeView.swift`
- `docs/season-comeback-catchup-buff-v1.md`
- `docs/supabase-schema-v1.md`
- `docs/supabase-migration.md`
- `docs/release-regression-checklist-v1.md`
- `docs/cycle-145-season-catchup-buff-report-2026-02-27.md`
- `scripts/season_comeback_catchup_unit_check.swift`
- `scripts/release_regression_checklist_unit_check.swift`
- `scripts/ios_pr_check.sh`
- `README.md`

## 4. 유닛 체크
- `swift scripts/season_comeback_catchup_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 현재 Home 배너는 마지막 points 동기화 응답 기준 상태를 표시하므로, 장시간 앱 미사용 시 만료 시점은 재동기화 후 정확히 갱신된다.
- 원격 DB QA(`supabase migration list --linked`, 실데이터 쿼리)는 세션별 `SUPABASE_DB_PASSWORD` 환경변수 설정이 필요하다.
