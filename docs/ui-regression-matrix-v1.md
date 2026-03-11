# UI Regression Matrix v1

## 목적
- 문서 스펙과 실제 UI 회귀 테스트를 직접 연결한다.
- 디자인 캡처 회귀와 기능 회귀를 별도 실행 경로로 분리한다.
- 고위험 유스케이스의 자동 테스트와 수동 QA 체크리스트를 같은 문서에서 관리한다.

## 실행 경로
- 디자인 감사 캡처: `bash scripts/run_design_audit_ui_tests.sh`
- 기능 회귀 UI: `bash scripts/run_feature_regression_ui_tests.sh`
- 위젯 액션 기능 회귀 UI: `bash scripts/run_widget_action_regression_ui_tests.sh`
- 문서/테스트 정합성 체크: `swift scripts/ui_regression_matrix_unit_check.swift`

## 문서-화면-테스트 매핑
| Case ID | 기준 문서 | 사용자 플로우 | 자동 검증 | 수동 QA 포인트 |
| --- | --- | --- | --- | --- |
| `DA-HOME-001` | `docs/home-goal-tracker-ui-v1.md` | 홈 라이트/다크 캡처 | `DesignAuditUITests/testDesignAudit_LightMode`, `DesignAuditUITests/testDesignAudit_DarkMode` | 인사말/주간 카드/영역 목표 카드 간격 확인 |
| `FR-MAP-001` | `docs/walk-start-stop-ux-v1.md` | 지도 진입 후 산책 시작 버튼 노출 | `FeatureRegressionUITests/testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar` | 실제 기기에서 탭바가 CTA를 가리지 않는지 확인 |
| `FR-MAP-002` | `docs/walk-start-stop-ux-v1.md` | 산책 시작 후 영역 추가 버튼 노출/터치 | `FeatureRegressionUITests/testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking` | 산책 중 영역 추가 버튼이 CTA와 겹치지 않고 눌리는지 확인 |
| `FR-MAP-002A` | `docs/map-add-point-walking-deck-separation-v1.md`, `#613` | 산책 중 영역 추가 스택이 walking control bar footprint 위에서 분리되는지 | `FeatureRegressionUITests/testFeatureRegression_MapAddPointSupportStackClearsWalkingDeckFootprint` | 작은 화면에서도 `+` 버튼과 보조 pill이 우측 진행 deck 위를 침범하지 않는지 확인 |
| `FR-MAP-003` | `docs/walk-start-stop-ux-v1.md`, `#451` | 산책 종료 알럿의 행동 위계 노출 | `FeatureRegressionUITests/testFeatureRegression_MapStopAlertPresentsClearActionHierarchy` | 저장 후 종료 / 계속 걷기 / 기록 폐기 우선순위가 즉시 이해되는지 확인 |
| `FR-MAP-004` | `docs/walk-value-flow-onboarding-v1.md`, `#565` | 지도 첫 진입 시 산책 가치 설명 가이드 자동 노출 | `FeatureRegressionUITests/testFeatureRegression_MapWalkValueGuideAutoPresentsOnFirstVisit` | 첫 산책 사용자가 시작 전/진행 중/저장 후 흐름을 한 번에 이해할 수 있는지 확인 |
| `FR-MAP-005` | `docs/walk-value-flow-onboarding-v1.md`, `#565` | 산책 진행 중 slim HUD와 저장 후 후속 행동 카드 연결 | `FeatureRegressionUITests/testFeatureRegression_MapWalkValueFlowExplainsDuringAndAfterSaving` | 진행 중 기록 의미, 저장 후 어디서 다시 보는지가 자연스럽게 이어지는지 확인 |
| `FR-MAP-005C` | `docs/walk-result-report-analytics-instrumentation-v1.md`, `#721` | 저장 직후 후속 카드에서 방금 저장한 산책 상세 리포트로 즉시 진입 | `FeatureRegressionUITests/testFeatureRegression_MapSavedOutcomeCardOpensImmediateDetailReport` | 저장 직후 목록을 거치지 않고도 결과 리포트와 문의 CTA까지 바로 확인할 수 있는지 확인 |
| `FR-MAP-005A` | `docs/map-hud-disclosure-policy-v1.md`, `#618` | 지도 시작 전 의미 카드가 기본 축약 상태를 유지하고 명시적 disclosure 후에만 확장되는지 | `FeatureRegressionUITests/testFeatureRegression_MapStartMeaningDisclosureExpandsOnlyWhenRequested` | 시작 전에는 CTA와 지도 본면이 먼저 읽히고, 사용자가 원할 때만 설명이 펴지는지 확인 |
| `FR-MAP-005B` | `docs/map-hud-disclosure-policy-v1.md`, `#618` | 산책 중 slim HUD가 기본 축약 상태를 유지하고 명시적 disclosure 후에만 상세 helper를 여는지 | `FeatureRegressionUITests/testFeatureRegression_MapWalkingHUDDisclosureExpandsOnlyWhenRequested` | 산책 중에도 상태 HUD가 상시 크게 열리지 않고, 자세한 설명은 사용자가 직접 펼칠 때만 보이는지 확인 |
| `FR-MAP-006` | `docs/map-bottom-controller-anchored-density-v1.md`, `#620` | 지도 idle 하단 컨트롤러가 얇고 탭바에 인접한 control bar로 유지되는지 | `FeatureRegressionUITests/testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactAtRest` | 시작 전 deck가 과도하게 떠 있지 않고, 탭바 위에 안정적으로 붙어 읽히는지 확인 |
| `FR-MAP-007` | `docs/map-bottom-controller-anchored-density-v1.md`, `#620` | 지도 walking 하단 컨트롤러가 더 낮은 footprint budget으로 유지되는지 | `FeatureRegressionUITests/testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactWhileWalking` | 산책 중 add-point/floating controls/selected tray와 함께 보여도 하단 stack이 두껍게 느껴지지 않는지 확인 |
| `FR-MAP-008` | `docs/map-top-slim-hud-safearea-v1.md`, `#619` | 산책 중 slim HUD가 safe area 아래 top chrome에 고정되고 하단 control bar와 분리되는지 | `FeatureRegressionUITests/testFeatureRegression_MapWalkingTopHUDStaysBelowSafeAreaAndAboveBottomControls` | 작은 화면에서도 상단 HUD가 1~2줄로 유지되고 하단 조작 deck와 역할이 분리되어 읽히는지 확인 |
| `FR-HOME-001` | `docs/home-top-safearea-contract-v1.md`, `#628` | 긴 이름/큰 글자 크기에서도 홈 헤더가 status bar 아래에 유지되는지 | `FeatureRegressionUITests/testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames` | 작은 화면과 접근성 글자 크기에서 인사말/부제가 safe area 아래로 안정적으로 감싸지는지 확인 |
| `FR-TABROOT-001` | `docs/non-map-tab-root-top-inset-contract-v1.md`, `docs/non-map-custom-header-safearea-contract-v1.md`, `#630`, `#678`, `#689` | 홈/산책 기록/라이벌/설정 루트 헤더가 같은 non-map top inset과 fixed top chrome 계약을 따르는지 | `FeatureRegressionUITests/testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar`, `FeatureRegressionUITests/testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames`, `FeatureRegressionUITests/testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle`, `FeatureRegressionUITests/testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar` | 작은 화면과 접근성 글자 크기에서 비지도 탭 루트 헤더가 status bar 아래에 안정적으로 시작하고, 스크롤해도 헤더 chrome이 본문과 분리된 상단 위치를 유지하는지 확인 |
| `FR-HOME-002` | `docs/walk-primary-loop-information-hierarchy-v1.md`, `#566` | 홈/지도 첫 화면에서 산책이 기본 루프로 읽히는지 | `FeatureRegressionUITests/testFeatureRegression_HomeAndMapPrioritizeWalkingAsPrimaryLoop` | 홈에서 산책 기본 루프 카드가 미션보다 먼저 읽히고, 지도 시작 덱의 compact 의미 카드가 CTA 역할을 보강하는지 확인 |
| `FR-HOME-002A` | `docs/walk-primary-loop-information-hierarchy-v1.md`, `#611` | 홈 기본 루프 카드가 compact summary를 유지하고 자세한 설명은 명시적 guide sheet로만 여는지 | `FeatureRegressionUITests/testFeatureRegression_HomeWalkPrimaryLoopCardStaysCompactAndOpensGuideOnDemand` | 홈 첫 화면이 장문 onboarding 카드처럼 보이지 않고, 필요한 설명만 별도 guide에서 읽히는지 확인 |
| `FR-WALK-001` | `docs/walklist-design-refresh-v1.md` | 산책 목록 첫 진입 시 핵심 카드/셀 접근 가능 | `FeatureRegressionUITests/testFeatureRegression_WalkListPrimaryContentIsNotObscuredByTabBar` | 작은 화면에서도 첫 셀/상태 카드가 탭바에 가리지 않는지 확인 |
| `FR-WALK-002` | `docs/walklist-design-refresh-v1.md` | 산책 목록 상단 허브의 요약/필터 문맥 노출 | `FeatureRegressionUITests/testFeatureRegression_WalkListHeaderSurfacesOverviewAndContextCards` | 상단 허브가 요약 카드, 필터 문맥, 게스트 CTA를 함께 설명하는지 확인 |
| `FR-WALK-002B` | `docs/walklist-hub-density-compact-v1.md`, `#623` | 산책 기록 상단 허브가 장문 onboarding 없이 compact한 정보 카드 밀도를 유지하는지 | `FeatureRegressionUITests/testFeatureRegression_WalkListHeaderCardsStayCompactWithoutVerboseOnboardingCopy` | 기본 행동/기준 카드가 짧은 카피와 일정한 패딩으로 요약 카드보다 무겁지 않게 읽히는지 확인 |
| `FR-WALK-002C` | `docs/walklist-top-safearea-contract-v1.md`, `#622`, `#689` | 산책 기록 sticky section header가 스크롤 중 고정 top chrome 바로 아래에 유지되는지 | `FeatureRegressionUITests/testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar` | `nonMapRootPinnedHeaderLayout`으로 루트 chrome과 scroll container가 분리된 상태에서 첫 섹션 헤더가 `walklist.header.section` 바로 아래에 pin 되는지 확인 |
| `FR-WALK-001B` | `docs/walklist-metric-tile-density-v1.md`, `#625` | 산책 기록 카드 메트릭 타일의 설명 제거와 compact 밀도 유지 | `FeatureRegressionUITests/testFeatureRegression_WalkListMetricTilesStayCompactWithoutVerboseCopy` | 샘플 기록 카드에서 4개 타일이 장문 설명 없이 같은 리듬으로 읽히는지 확인 |
| `FR-WALK-001C` | `docs/walklist-metric-tile-density-v1.md`, `docs/ui-overlap-ellipsis-small-screen-policy-v1.md`, `#625`, `#739` | 작은 화면과 긴 값 조건에서도 산책 기록 카드 타일이 겹치지 않고 같은 높이 리듬을 유지하는지 | `FeatureRegressionUITests/testFeatureRegression_WalkListLongMetricTilesStayUniformOnSmallScreen` | 긴 면적 값, 긴 반려견 이름, 접근성 글자 크기 조합에서도 셀 높이가 과도하게 커지지 않고 같은 줄 타일 높이가 균일한지 확인 |
| `FR-WALK-002A` | `docs/walk-record-tab-label-v1.md`, `#621` | 탭바와 접근성 표면에서 산책 기록 명칭 유지 | `FeatureRegressionUITests/testFeatureRegression_WalkListTabSelectedIconRemainsVisibleInBothStyles` | 탭 버튼이 `산책 기록`으로 읽히고 선택 상태 심볼도 함께 유지되는지 확인 |
| `FR-WALK-003` | `docs/walklist-detail-design-refresh-v1.md`, `#530` | 산책 상세의 요약/지도/타임라인/CTA 위계 | `FeatureRegressionUITests/testFeatureRegression_WalkListDetailClarifiesSummaryAndActionHierarchy` | 상세 화면에서 공유가 주행동, 저장이 보조, 확인이 dismiss로 읽히는지 확인 |
| `FR-WALK-003C` | `docs/walk-result-report-analytics-instrumentation-v1.md`, `#721` | 저장된 산책 상세 결과 리포트의 disclosure·문의 CTA 노출 | `FeatureRegressionUITests/testFeatureRegression_WalkListDetailOutcomeReportExplainsAppliedExcludedAndConnections` | 반영/제외/연결/계산 근거 disclosure와 문의 CTA가 같은 결과 리포트 카드 안에서 읽히는지 확인 |
| `FR-WALK-003B` | `docs/walk-detail-back-affordance-v1.md`, `#626` | 산책 상세 상단 back affordance 복구와 stack 복귀 | `FeatureRegressionUITests/testFeatureRegression_WalkListDetailRestoresTopBackAffordance` | 상단 back affordance가 보이고, 탭 시 자연스럽게 산책 기록 화면으로 돌아가는지 확인 |
| `FR-WALK-003A` | `docs/walk-detail-share-system-sheet-v1.md`, `#627` | 산책 상세 공유 CTA가 빈 모달 없이 시스템 share presenter를 직접 연다 | `FeatureRegressionUITests/testFeatureRegression_WalkListShareActionPresentsSystemSharePresenter` | 공유 CTA 탭 직후 시스템 share presenter 활성 마커가 노출되는지 확인 |
| `FR-WALK-004` | `docs/walklist-month-calendar-hub-v1.md`, `#567` | 월별 캘린더 날짜 탭이 즉시 날짜 필터로 이어지는지 | `FeatureRegressionUITests/testFeatureRegression_WalkListCalendarSelectionFiltersToChosenDate` | 자정 걸침 세션을 포함한 날짜 기준 탐색이 바로 리스트에 반영되는지 확인 |
| `FR-WALK-004A` | `docs/walklist-calendar-weekend-holiday-semantic-v1.md`, `#624` | weekday header와 날짜 셀이 같은 주말 semantic을 유지하는지 | `FeatureRegressionUITests/testFeatureRegression_WalkListCalendarWeekendSemanticLabelsStayConsistent` | 토요일/일요일 semantic이 header와 날짜 셀 접근성 표면에 일관되게 남는지 확인 |
| `FR-GOAL-001` | `docs/home-goal-tracker-ui-v1.md`, `docs/territory-goal-view-detail-ui-v1.md` | 홈 목표 상세 진입/복귀 | `FeatureRegressionUITests/testFeatureRegression_TerritoryGoalNavigationHidesAndRestoresTabBar` | 상세 진입 시 탭바 숨김, 복귀 시 재노출 확인 |
| `FR-HOME-QUEST-001` | `docs/home-goal-tracker-ui-v1.md`, `#453` | 홈 미션 카드의 완료 기준/아카이브 상태 분리 | `FeatureRegressionUITests/testFeatureRegression_HomeMissionLifecycleSeparatesCompletedMissionState` | 완료 미션이 별도 아카이브로 이동하고 자가 기록 가이드가 노출되는지 확인 |
| `FR-HOME-QUEST-002` | `docs/home-quest-help-layer-v1.md`, `#564` | 홈 미션 도움말 코치 카드와 재진입 sheet | `FeatureRegressionUITests/testFeatureRegression_HomeMissionHelpLayerExplainsWhatWhyHowAndOutcome` | 5초 안에 무엇/왜/어떻게/완료 후 변화와 자동/자가 기록 차이를 이해할 수 있는지 확인 |
| `FR-HOME-QUEST-003` | `docs/home-quest-tracking-mode-guideline-v1.md`, `#563` | 홈 미션 카드 표면에서 자동 기록형/직접 체크형 구분 | `FeatureRegressionUITests/testFeatureRegression_HomeMissionCardDifferentiatesAutoAndManualTrackingModes` | 버튼을 누르기 전에 자동 반영과 직접 체크 규칙 차이가 즉시 읽히는지 확인 |
| `FR-AUTH-001` | `docs/profile-edit-flow-v1.md`, `docs/supabase-auth-apple-plan.md` | 설정 탭의 로그인/로그아웃 진입점 | `FeatureRegressionUITests/testFeatureRegression_SettingsAuthEntryPoints` | guest/member 상태별 CTA 문구 확인 |
| `FR-SET-001` | `docs/profile-edit-flow-v1.md` | 설정 메인 카드의 사용자/반려견 이미지 탭 편집 진입 | `FeatureRegressionUITests/testFeatureRegression_SettingsImageTapAffordanceOpensProfileEdit` | 이미지 자체가 1차 편집 진입점으로 이해되는지 확인 |
| `FR-SET-002` | `docs/privacy-deletion-request-intake-tracking-v1.md`, `#720` | 설정 프라이버시 센터의 삭제 요청 흐름 진입 | `FeatureRegressionUITests/testFeatureRegression_SettingsPrivacyDeletionRequestFlowExplainsNextSteps` | 삭제 요청 시트에서 요청 ID, 수집 항목, 다음 단계, 전송/문의 액션이 한 흐름으로 읽히는지 확인 |
| `FR-PROFILE-001` | `docs/profile-edit-flow-v1.md` | 회원 상태 프로필 편집 저장 | `FeatureRegressionUITests/testFeatureRegression_MemberProfileEditPersistsUpdatedPetName` | 프로필 편집 저장 후 재진입 시 값 유지 확인 |
| `FR-RIVAL-001` | `docs/rival-tab-ui-design-spec-v1.md`, `docs/nearby-anonymous-hotspot-v1.md` | 로그아웃 후 재로그인, 익명 공유 시작 | `FeatureRegressionUITests/testFeatureRegression_RivalAuthRevalidationFlow` | 세션 재검증 후 공유 시작 가능 여부 확인 |
| `FR-RIVAL-002` | `docs/rival-tab-ui-design-spec-v1.md` | 라이벌 푸터 버튼 라우팅 | `FeatureRegressionUITests/testFeatureRegression_RivalFooterButtonsRouteToMapAndSettings` | 지도/설정으로의 전환 및 복귀 확인 |
| `FR-RIVAL-003` | `docs/rival-top-safearea-contract-v1.md`, `#629` | 긴 부제/큰 글자 크기에서도 라이벌 헤더와 첫 배지 행이 status bar 아래에 유지되는지 | `FeatureRegressionUITests/testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle` | 작은 화면과 접근성 글자 크기에서 라이벌 제목/부제/배지 행이 safe area 아래로 안정적으로 감싸지는지 확인 |
| `FR-WIDGET-001` | `docs/hotspot-widget-privacy-mapping-v1.md` | 위젯 기본 딥링크 라우트 | `FeatureRegressionUITests/testFeatureRegression_WidgetRouteOpensRivalTab` | 위젯 탭 후 라이벌 탭 진입과 첫 상태 표시 확인 |
| `FR-WIDGET-002` | `docs/hotspot-widget-radius-preset-v1.md`, `docs/widget-action-real-device-validation-matrix-v1.md` | 핫스팟 위젯 preset 라우트 | `FeatureRegressionUITests/testFeatureRegression_HotspotWidgetRouteOpensRivalWithMatchingRadiusPreset` | 실기기에서 3km preset이 cold start / foreground 모두에서 동일하게 유지되는지 확인 |
| `FR-WIDGET-003` | `docs/quest-rival-widget-next-action-recovery-v1.md`, `docs/widget-action-real-device-validation-matrix-v1.md` | 퀘스트 위젯 상세 CTA 라우트 | `FeatureRegressionUITests/testFeatureRegression_QuestWidgetRouteOpensQuestMissionBoard` | background 상태에서도 홈 퀘스트 카드 위치와 상세 배너가 같이 복구되는지 확인 |
| `FR-WIDGET-004` | `docs/quest-rival-widget-next-action-recovery-v1.md`, `docs/widget-action-real-device-validation-matrix-v1.md` | 퀘스트 위젯 recovery CTA 라우트 | `FeatureRegressionUITests/testFeatureRegression_QuestWidgetRecoveryRouteOpensQuestMissionBoard` | foreground 상태에서도 recovery 배너와 미션 카드 위치가 같이 노출되는지 확인 |
| `FR-WIDGET-005` | `docs/territory-widget-goal-deeplink-v1.md`, `docs/widget-action-real-device-validation-matrix-v1.md` | 영역 위젯 목표 상세 딥링크 | `FeatureRegressionUITests/testFeatureRegression_TerritoryWidgetRouteOpensGoalDetail` | 실기기에서 cold start 진입 시 목표 상세 직접 진입과 탭바 숨김이 유지되는지 확인 |
| `QA-MULTIPET-001` | `docs/multi-dog-selection-ux-v1.md`, `docs/multi-pet-session-nm-v2.md` | 다견 선택/활성 상태 전환 | `swift scripts/multi_dog_selection_ux_unit_check.swift`, `swift scripts/settings_pet_management_unit_check.swift` | 선택 반려견 변경 후 홈/목록/설정 반영 확인 |

## 수동 QA 체크리스트
- `QA-AUTH-01`: 로그인 후 홈, 지도, 라이벌, 설정이 같은 세션 상태를 공유한다.
- `QA-PROFILE-01`: 프로필 편집에서 사용자 이름, 프로필 메시지, 반려견 이름이 저장 후 다시 열린다.
- `QA-PET-01`: 반려견 관리에서 대표 변경과 활성/비활성 전환이 설정/홈/목록에 동시에 반영된다.
- `QA-GOAL-01`: 홈 카드와 목표 상세 화면이 정보 구조상 중복되지 않고, 상세 화면에서 더 많은 문맥을 제공한다.
- `QA-RIVAL-01`: 라이벌 탭에서 권한/동의/공유 ON/OFF 상태가 토스트와 배지에 일관되게 반영된다.
- `QA-WIDGET-01`: 위젯 경로는 앱이 이미 살아있는 상태와 cold start 상태 모두에서 동일한 탭으로 도착한다.
- `QA-WIDGET-02`: 실기기 검증 결과는 `docs/widget-action-real-device-validation-matrix-v1.md`에 남기고, `cold start / background / foreground / auth state / action` 축을 모두 채운다.

## 운영 규칙
- 디자인 스크린샷 감사와 기능 회귀는 같은 파일/같은 스크립트에서 실행하지 않는다.
- 기능 회귀 UI 테스트는 네트워크 가변성이 큰 저장/업로드 경로에 대해 UI 테스트 전용 스텁을 허용한다.
- 실제 서버 연동 검증이 필요한 항목은 UI 테스트 대신 별도 smoke/manual QA로 분리한다.
