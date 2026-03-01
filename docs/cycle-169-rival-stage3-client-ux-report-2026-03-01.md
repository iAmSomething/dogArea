# Cycle #169 - Rival Stage3 Client UX Report (2026-03-01)

## 처리 이슈
- #132 `[Task][Rival][Stage 3] 라이벌 비교 UI/신고·차단 UX 구현`

## 구현 요약
- 라이벌 탭 스켈레톤을 실제 비교 UX로 전환했습니다.
- 주간/시즌 리더보드 조회(점수 버킷 기반)와 라이벌/친구 범위 토글을 추가했습니다.
- 신고/차단/숨기기 액션을 리더보드 행 메뉴로 제공하고 즉시 UI 반영되도록 구현했습니다.
- 숨김/차단 관리 시트를 추가해 해제 동작을 지원했습니다.
- opt-out(익명 공유 OFF) 시 핫스팟/리더보드가 즉시 비활성화되도록 상태 전이를 강화했습니다.

## 변경 파일
- `dogArea/Views/ProfileSettingView/NotificationCenterView.swift`
- `dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift`
- `scripts/rival_stage3_client_ux_unit_check.swift`
- `scripts/ios_pr_check.sh`
- `docs/rival-stage3-client-ux-v1.md`
- `README.md`

## 검증 결과
- `swift scripts/rival_stage3_client_ux_unit_check.swift` PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` PASS
- `xcodebuild -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build` PASS

## 비고
- 친구 비교 데이터는 Stage3에서 프리뷰 탭 상태로 노출하며, 실데이터 연결은 후속 단계에서 진행합니다.
- 신고 로그는 로컬 저장 기반으로 먼저 제공하고, 서버 접수 파이프라인은 후속 이슈에서 확장합니다.
