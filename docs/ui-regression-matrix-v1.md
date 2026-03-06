# UI Regression Matrix v1

## 목적
- 문서 스펙과 실제 UI 회귀 테스트를 직접 연결한다.
- 디자인 캡처 회귀와 기능 회귀를 별도 실행 경로로 분리한다.
- 고위험 유스케이스의 자동 테스트와 수동 QA 체크리스트를 같은 문서에서 관리한다.

## 실행 경로
- 디자인 감사 캡처: `bash scripts/run_design_audit_ui_tests.sh`
- 기능 회귀 UI: `bash scripts/run_feature_regression_ui_tests.sh`
- 문서/테스트 정합성 체크: `swift scripts/ui_regression_matrix_unit_check.swift`

## 문서-화면-테스트 매핑
| Case ID | 기준 문서 | 사용자 플로우 | 자동 검증 | 수동 QA 포인트 |
| --- | --- | --- | --- | --- |
| `DA-HOME-001` | `docs/home-goal-tracker-ui-v1.md` | 홈 라이트/다크 캡처 | `DesignAuditUITests/testDesignAudit_LightMode`, `DesignAuditUITests/testDesignAudit_DarkMode` | 인사말/주간 카드/영역 목표 카드 간격 확인 |
| `FR-MAP-001` | `docs/walk-start-stop-ux-v1.md` | 지도 진입 후 산책 시작 버튼 노출 | `FeatureRegressionUITests/testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar` | 실제 기기에서 탭바가 CTA를 가리지 않는지 확인 |
| `FR-GOAL-001` | `docs/home-goal-tracker-ui-v1.md`, `docs/territory-goal-view-detail-ui-v1.md` | 홈 목표 상세 진입/복귀 | `FeatureRegressionUITests/testFeatureRegression_TerritoryGoalNavigationHidesAndRestoresTabBar` | 상세 진입 시 탭바 숨김, 복귀 시 재노출 확인 |
| `FR-AUTH-001` | `docs/profile-edit-flow-v1.md`, `docs/supabase-auth-apple-plan.md` | 설정 탭의 로그인/로그아웃 진입점 | `FeatureRegressionUITests/testFeatureRegression_SettingsAuthEntryPoints` | guest/member 상태별 CTA 문구 확인 |
| `FR-PROFILE-001` | `docs/profile-edit-flow-v1.md` | 회원 상태 프로필 편집 저장 | `FeatureRegressionUITests/testFeatureRegression_MemberProfileEditPersistsUpdatedPetName` | 프로필 편집 저장 후 재진입 시 값 유지 확인 |
| `FR-RIVAL-001` | `docs/rival-tab-ui-design-spec-v1.md`, `docs/nearby-anonymous-hotspot-v1.md` | 로그아웃 후 재로그인, 익명 공유 시작 | `FeatureRegressionUITests/testFeatureRegression_RivalAuthRevalidationFlow` | 세션 재검증 후 공유 시작 가능 여부 확인 |
| `FR-RIVAL-002` | `docs/rival-tab-ui-design-spec-v1.md` | 라이벌 푸터 버튼 라우팅 | `FeatureRegressionUITests/testFeatureRegression_RivalFooterButtonsRouteToMapAndSettings` | 지도/설정으로의 전환 및 복귀 확인 |
| `FR-WIDGET-001` | `docs/hotspot-widget-privacy-mapping-v1.md` | 위젯 기본 딥링크 라우트 | `FeatureRegressionUITests/testFeatureRegression_WidgetRouteOpensRivalTab` | 위젯 탭 후 라이벌 탭 진입과 첫 상태 표시 확인 |
| `QA-MULTIPET-001` | `docs/multi-dog-selection-ux-v1.md`, `docs/multi-pet-session-nm-v2.md` | 다견 선택/활성 상태 전환 | `swift scripts/multi_dog_selection_ux_unit_check.swift`, `swift scripts/settings_pet_management_unit_check.swift` | 선택 반려견 변경 후 홈/목록/설정 반영 확인 |

## 수동 QA 체크리스트
- `QA-AUTH-01`: 로그인 후 홈, 지도, 라이벌, 설정이 같은 세션 상태를 공유한다.
- `QA-PROFILE-01`: 프로필 편집에서 사용자 이름, 프로필 메시지, 반려견 이름이 저장 후 다시 열린다.
- `QA-PET-01`: 반려견 관리에서 대표 변경과 활성/비활성 전환이 설정/홈/목록에 동시에 반영된다.
- `QA-GOAL-01`: 홈 카드와 목표 상세 화면이 정보 구조상 중복되지 않고, 상세 화면에서 더 많은 문맥을 제공한다.
- `QA-RIVAL-01`: 라이벌 탭에서 권한/동의/공유 ON/OFF 상태가 토스트와 배지에 일관되게 반영된다.
- `QA-WIDGET-01`: 위젯 경로는 앱이 이미 살아있는 상태와 cold start 상태 모두에서 동일한 탭으로 도착한다.

## 운영 규칙
- 디자인 스크린샷 감사와 기능 회귀는 같은 파일/같은 스크립트에서 실행하지 않는다.
- 기능 회귀 UI 테스트는 네트워크 가변성이 큰 저장/업로드 경로에 대해 UI 테스트 전용 스텁을 허용한다.
- 실제 서버 연동 검증이 필요한 항목은 UI 테스트 대신 별도 smoke/manual QA로 분리한다.
