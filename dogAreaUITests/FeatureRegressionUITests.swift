import XCTest

/// 기능 회귀 시나리오를 사용자 플로우 단위로 검증하는 UI 테스트입니다.
final class FeatureRegressionUITests: XCTestCase {
    private enum InterfaceStyle: String {
        case light
        case dark
    }

    private struct TestCredentials {
        let email: String
        let password: String
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 지도 탭의 주행동 버튼이 하단 탭바에 가려지지 않고 탭 가능한지 검증합니다.
    func testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(openTab(index: 2, app: app), "지도 탭 진입에 실패했습니다.")
        XCTAssertTrue(waitUntilMapReady(app), "지도 탭 준비가 완료되지 않았습니다.")

        let primaryAction = mapPrimaryAction(in: app)
        if waitUntilExists(primaryAction, timeout: 12) == false {
            dumpMapAccessibilityCandidates(app)
        }
        XCTAssertTrue(waitUntilExists(primaryAction, timeout: 1), "지도 산책 시작 버튼을 찾지 못했습니다.")
        XCTAssertTrue(primaryAction.isHittable, "지도 산책 시작 버튼이 하단 탭바에 가려져 탭 불가능합니다.")
    }

    /// 회원 상태로 산책을 시작한 뒤 영역 추가 버튼이 가려지지 않고 탭 가능한지 검증합니다.
    func testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking() throws {
        let app = launchAppForFeatureRegression(extraArguments: ["-UITest.MapForceWalkingState"])

        XCTAssertTrue(openTab(index: 2, app: app), "지도 탭 진입에 실패했습니다.")
        XCTAssertTrue(waitUntilMapReady(app), "지도 탭 준비가 완료되지 않았습니다.")

        let addPointButton = app.buttons["map.addPoint"]
        XCTAssertTrue(
            waitUntilExists(addPointButton, timeout: 8),
            "산책 중 상태에서 영역 추가 버튼이 나타나지 않았습니다."
        )
        XCTAssertTrue(
            waitUntilHittable(addPointButton, timeout: 2),
            "산책 중 영역 추가 버튼이 다른 오버레이에 가려져 탭 불가능합니다."
        )
    }

    /// 산책 목록 탭의 핵심 콘텐츠 진입점이 하단 탭바에 가려지지 않는지 검증합니다.
    func testFeatureRegression_WalkListPrimaryContentIsNotObscuredByTabBar() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(openTab(index: 1, app: app), "산책 목록 탭 진입에 실패했습니다.")

        let walkListScreen = screenElement(identifier: "screen.walkList.content", in: app)
        XCTAssertTrue(waitUntilExists(walkListScreen, timeout: 8), "산책 목록 화면 렌더링에 실패했습니다.")

        let firstCell = app.descendants(matching: .any).matching(identifier: "walklist.cell").firstMatch
        if waitUntilExists(firstCell, timeout: 2) {
            XCTAssertTrue(firstCell.isHittable, "산책 목록 셀이 하단 탭바에 가려져 탭 불가능합니다.")
            return
        }

        let guestLoginButton = app.buttons["walklist.guest.login"]
        if waitUntilExists(guestLoginButton, timeout: 2) {
            XCTAssertTrue(guestLoginButton.isHittable, "산책 목록 게스트 로그인 버튼이 하단 탭바에 가려져 탭 불가능합니다.")
            return
        }

        let emptyCard = app.otherElements["walklist.empty"]
        XCTAssertTrue(waitUntilExists(emptyCard, timeout: 2), "산책 목록 탭의 기본 비어 있음 상태를 찾지 못했습니다.")
    }

    /// 홈의 영역 목표 상세 진입 시 탭바가 숨겨지고 뒤로 복귀 시 다시 표시되는지 검증합니다.
    func testFeatureRegression_TerritoryGoalNavigationHidesAndRestoresTabBar() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(waitUntilExists(app.buttons["tab.0"], timeout: 12), "탭바가 렌더링되지 않았습니다.")
        XCTAssertTrue(openTab(index: 0, app: app), "홈 탭 진입에 실패했습니다.")

        let moreButton = app.buttons["home.goalTracker.more"]
        XCTAssertTrue(
            revealElementByVerticalScroll(moreButton, app: app, maxSwipes: 8),
            "영역 목표 트래커의 비교군 더보기 버튼을 찾지 못했습니다."
        )
        XCTAssertTrue(
            waitUntilHittable(moreButton, timeout: 2),
            "영역 목표 트래커의 비교군 더보기 버튼이 탭 가능한 상태로 안정화되지 않았습니다."
        )
        XCTAssertTrue(tapIfExists(moreButton), "영역 목표 트래커의 비교군 더보기 버튼 탭에 실패했습니다.")

        let territoryGoalScreen = screenElement(identifier: "screen.territoryGoal", in: app)
        if waitUntilExists(territoryGoalScreen, timeout: 10) == false {
            dumpTerritoryGoalAccessibilityCandidates(app)
        }
        XCTAssertTrue(
            waitUntilExists(territoryGoalScreen, timeout: 1),
            "영역 목표 상세 화면 진입에 실패했습니다."
        )
        XCTAssertTrue(
            waitUntilGone(app.buttons["tab.2"], timeout: 3),
            "영역 목표 상세 화면에서는 하단 탭바가 숨겨져야 합니다."
        )

        navigateBackIfPossible(app)
        XCTAssertTrue(waitUntilExists(app.buttons["tab.2"], timeout: 6), "상세 화면 복귀 후 하단 탭바가 다시 표시되지 않았습니다.")
    }

    /// 목표 상세에서 비교군 카탈로그로 2단계 진입했을 때 카탈로그 전용 섹션이 분리되어 노출되는지 검증합니다.
    func testFeatureRegression_TerritoryGoalOpensSeparatedAreaDetailCatalog() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(waitUntilExists(app.buttons["tab.0"], timeout: 12), "탭바가 렌더링되지 않았습니다.")
        XCTAssertTrue(openTab(index: 0, app: app), "홈 탭 진입에 실패했습니다.")

        let moreButton = app.buttons["home.goalTracker.more"]
        XCTAssertTrue(
            revealElementByVerticalScroll(moreButton, app: app, maxSwipes: 8),
            "영역 목표 트래커의 목표 상세 보기 버튼을 찾지 못했습니다."
        )
        XCTAssertTrue(tapIfExists(moreButton), "영역 목표 상세 화면 진입에 실패했습니다.")

        let territoryGoalScreen = screenElement(identifier: "screen.territoryGoal", in: app)
        XCTAssertTrue(waitUntilExists(territoryGoalScreen, timeout: 10), "영역 목표 상세 화면 렌더링에 실패했습니다.")

        let catalogButton = app.buttons["territory.goal.catalog"]
        XCTAssertTrue(waitUntilExists(catalogButton, timeout: 4), "비교군 카탈로그 CTA를 찾지 못했습니다.")
        XCTAssertTrue(tapIfExists(catalogButton), "비교군 카탈로그 CTA 탭에 실패했습니다.")

        let areaDetailScreen = screenElement(identifier: "screen.areaDetail", in: app)
        XCTAssertTrue(waitUntilExists(areaDetailScreen, timeout: 8), "비교군 카탈로그 화면 진입에 실패했습니다.")
        XCTAssertTrue(waitUntilGone(app.buttons["tab.2"], timeout: 2), "비교군 카탈로그 화면에서는 하단 탭바가 숨겨져야 합니다.")
        XCTAssertTrue(waitUntilExists(app.staticTexts["카탈로그 스냅샷"], timeout: 3), "비교군 카탈로그 스냅샷 섹션이 노출되지 않았습니다.")
        XCTAssertTrue(waitUntilExists(app.staticTexts["현재 위치와 다음 기준"], timeout: 3), "비교군 카탈로그 전용 요약 카드가 노출되지 않았습니다.")
    }

    /// 라이벌 탭 하단 푸터 버튼이 지도/설정 탭 라우팅을 정상 수행하는지 검증합니다.
    func testFeatureRegression_RivalFooterButtonsRouteToMapAndSettings() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(waitUntilExists(app.buttons["tab.3"], timeout: 12), "탭바가 렌더링되지 않았습니다.")
        XCTAssertTrue(openTab(index: 3, app: app), "라이벌 탭 진입에 실패했습니다.")

        let openMapButton = app.buttons["rival.footer.openMap"]
        XCTAssertTrue(
            revealElementByVerticalScroll(openMapButton, app: app, maxSwipes: 8),
            "라이벌 푸터의 지도 이동 버튼을 찾지 못했습니다."
        )
        openMapButton.tap()
        usleep(300_000)
        XCTAssertTrue(waitUntilMapReady(app), "지도 탭 라우팅 후 지도 준비가 완료되지 않았습니다.")
        XCTAssertTrue(waitUntilExists(mapPrimaryAction(in: app), timeout: 12), "지도 탭 라우팅 후 지도 주행동 버튼을 찾지 못했습니다.")

        XCTAssertTrue(openTab(index: 3, app: app), "라이벌 탭 재진입에 실패했습니다.")

        let openSettingsButton = app.buttons["rival.footer.openSettings"]
        XCTAssertTrue(
            revealElementByVerticalScroll(openSettingsButton, app: app, maxSwipes: 8),
            "라이벌 푸터의 설정 이동 버튼을 찾지 못했습니다."
        )
        openSettingsButton.tap()
        let signInButton = app.buttons["settings.open.signin"]
        let logoutButton = app.buttons["settings.logout"]

        if waitUntilExists(signInButton, timeout: 3) == false &&
            waitUntilExists(logoutButton, timeout: 3) == false {
            XCTAssertTrue(openTab(index: 4, app: app), "설정 탭 진입에 실패했습니다.")
        }
        let hasSettingsEntryPoint =
            waitUntilExists(signInButton, timeout: 4) ||
            waitUntilExists(logoutButton, timeout: 4)
        XCTAssertTrue(hasSettingsEntryPoint, "설정 탭 진입 화면 검증에 실패했습니다.")
    }

    /// 설정 탭에서 게스트/회원 상태별 핵심 진입점(로그인 또는 로그아웃)이 노출되는지 검증합니다.
    func testFeatureRegression_SettingsAuthEntryPoints() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(waitUntilExists(app.buttons["tab.4"], timeout: 12), "탭바가 렌더링되지 않았습니다.")
        XCTAssertTrue(openTab(index: 4, app: app), "설정 탭 진입에 실패했습니다.")

        let signInButton = app.buttons["settings.open.signin"]
        let logoutButton = app.buttons["settings.logout"]

        if waitUntilExists(signInButton, timeout: 3) {
            signInButton.tap()
            _ = presentSignInFlowIfNeeded(app)
            XCTAssertTrue(
                waitUntilExists(screenElement(identifier: "screen.signin", in: app), timeout: 6),
                "로그인 화면 진입에 실패했습니다."
            )
            _ = tapIfExists(app.buttons["signin.dismiss"])
            dismissTopModalIfNeeded(app)
            return
        }

        XCTAssertTrue(waitUntilExists(logoutButton, timeout: 3), "회원 상태 설정 진입점(로그아웃 버튼)을 찾지 못했습니다.")
        XCTAssertTrue(logoutButton.isHittable, "로그아웃 버튼이 탭 가능한 상태가 아닙니다.")
    }

    /// 설정 탭이 실제 앱 설정/법적 문서/지원/앱 정보 섹션을 모두 노출하는지 검증합니다.
    func testFeatureRegression_SettingsProductSectionsExposeOperationalEntries() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(waitUntilExists(app.buttons["tab.4"], timeout: 12), "탭바가 렌더링되지 않았습니다.")
        XCTAssertTrue(openTab(index: 4, app: app), "설정 탭 진입에 실패했습니다.")

        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["앱 설정"], app: app, maxSwipes: 8),
            "앱 설정 섹션 제목이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["시스템 설정 열기"], app: app, maxSwipes: 2),
            "앱 설정 섹션의 시스템 설정 행을 찾지 못했습니다."
        )

        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["개인정보 / 법적 문서"], app: app, maxSwipes: 6),
            "법적 문서 섹션 제목이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["개인정보처리방침"], app: app, maxSwipes: 2),
            "개인정보처리방침 행이 노출되지 않았습니다."
        )

        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["지원 / 문의"], app: app, maxSwipes: 6),
            "지원 섹션 제목이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["개발자 문의 메일"], app: app, maxSwipes: 2),
            "개발자 문의 메일 행이 노출되지 않았습니다."
        )

        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["앱 정보"], app: app, maxSwipes: 6),
            "앱 정보 섹션 제목이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            revealExistingElementByVerticalScroll(app.staticTexts["앱 버전"], app: app, maxSwipes: 2),
            "앱 버전 정보 행이 노출되지 않았습니다."
        )
    }

    /// 홈 미션 카드가 완료 기준/자가 기록 가이드/완료 아카이브 상태를 분리해 노출하는지 검증합니다.
    func testFeatureRegression_HomeMissionLifecycleSeparatesCompletedMissionState() throws {
        let app = launchAppForFeatureRegression(extraArguments: ["-UITest.HomeMissionLifecycleStub"])
        let dailyMissionCard = app.descendants(matching: .any).matching(identifier: "home.quest.card.daily").firstMatch
        let weatherStatusCard = app.descendants(matching: .any).matching(identifier: "home.quest.weatherStatus").firstMatch
        let rationaleCard = app.descendants(matching: .any).matching(identifier: "home.quest.rationale.card").firstMatch
        let activeSection = app.descendants(matching: .any).matching(identifier: "home.quest.section.active").firstMatch
        let completedSection = app.descendants(matching: .any).matching(identifier: "home.quest.section.completed").firstMatch
        let activeRow = app.descendants(matching: .any).matching(identifier: "home.quest.row.uitest.home.quest.active").firstMatch
        let readyRow = app.descendants(matching: .any).matching(identifier: "home.quest.row.uitest.home.quest.ready").firstMatch
        let completedRow = app.descendants(matching: .any).matching(identifier: "home.quest.row.uitest.home.quest.completed").firstMatch

        XCTAssertTrue(openTab(index: 0, app: app), "홈 탭 진입에 실패했습니다.")
        XCTAssertTrue(
            revealExistingElementByVerticalScroll(dailyMissionCard, app: app, maxSwipes: 6),
            "홈 미션 카드를 화면에 노출하지 못했습니다."
        )
        XCTAssertTrue(
            waitUntilExists(weatherStatusCard, timeout: 4),
            "날씨 연동 상태 카드가 노출되지 않았습니다."
        )
        XCTAssertTrue(
            waitUntilExists(rationaleCard, timeout: 4),
            "미션 진행 가이드 카드가 노출되지 않았습니다."
        )
        XCTAssertTrue(
            waitUntilExists(activeSection, timeout: 4),
            "진행 중 미션 섹션이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            waitUntilExists(completedSection, timeout: 4),
            "완료 미션 아카이브 섹션이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            waitUntilExists(activeRow, timeout: 4),
            "진행 중 미션 행이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            waitUntilExists(readyRow, timeout: 4),
            "완료 확정 가능 미션 행이 노출되지 않았습니다."
        )
        XCTAssertTrue(
            waitUntilExists(completedRow, timeout: 4),
            "완료 아카이브 미션 행이 노출되지 않았습니다."
        )
    }

    /// 회원 상태에서 프로필 편집 저장 성공 후 편집 값이 다시 시트에 반영되는지 검증합니다.
    func testFeatureRegression_MemberProfileEditPersistsUpdatedPetName() throws {
        let credentials = try XCTUnwrap(
            loadTestCredentials(),
            "DOGAREA_TEST_EMAIL/DOGAREA_TEST_PASSWORD 또는 .design_audit_credentials.json이 필요합니다."
        )
        let app = launchAppForFeatureRegression(extraArguments: ["-UITest.ProfileSaveStubSuccess"])

        XCTAssertTrue(openTab(index: 4, app: app), "설정 탭 진입에 실패했습니다.")
        XCTAssertTrue(
            ensureMemberSession(app: app, credentials: credentials),
            "회원 상태 진입에 실패했습니다."
        )

        XCTAssertTrue(openTab(index: 4, app: app), "로그인 후 설정 탭 재진입에 실패했습니다.")
        XCTAssertTrue(tapIfExists(app.buttons["settings.profile.edit"]), "프로필 편집 시트 진입에 실패했습니다.")
        let profileEditSheet = screenElement(identifier: "sheet.settings.profileEdit", in: app)
        XCTAssertTrue(waitUntilExists(profileEditSheet, timeout: 8), "프로필 편집 시트를 찾지 못했습니다.")

        let userNameField = app.textFields["settings.profile.field.userName"]
        XCTAssertTrue(waitUntilExists(userNameField, timeout: 4), "사용자 이름 입력 필드를 찾지 못했습니다.")
        replaceText(on: userNameField, with: "UITestUser")

        let petNameField = app.textFields["settings.profile.field.petName"]
        XCTAssertTrue(waitUntilExists(petNameField, timeout: 4), "반려견 이름 입력 필드를 찾지 못했습니다.")
        replaceText(on: petNameField, with: "UITestDog")
        XCTAssertTrue(tapIfExists(app.buttons["sheet.settings.profileEdit.save"]), "프로필 저장 버튼 탭에 실패했습니다.")
        if waitUntilGone(profileEditSheet, timeout: 8) == false {
            let errorLabel = app.staticTexts["sheet.settings.profileEdit.error"]
            let errorMessage = waitUntilExists(errorLabel, timeout: 1)
                ? errorLabel.label
                : "none"
            XCTFail("프로필 저장 후 시트가 닫히지 않았습니다. error=\(errorMessage)")
        }

        XCTAssertTrue(tapIfExists(app.buttons["settings.profile.edit"]), "저장 후 프로필 편집 시트 재진입에 실패했습니다.")
        XCTAssertTrue(waitUntilExists(profileEditSheet, timeout: 6), "저장 후 프로필 편집 시트를 다시 찾지 못했습니다.")
        XCTAssertEqual(petNameField.value as? String, "UITestDog", "저장한 반려견 이름이 다음 편집 진입 시 유지되어야 합니다.")
        _ = tapIfExists(app.buttons["sheet.settings.profileEdit.cancel"])
    }

    /// 설정 메인 카드의 사용자/반려견 이미지를 탭하면 동일한 프로필 편집 시트로 진입하는지 검증합니다.
    func testFeatureRegression_SettingsImageTapAffordanceOpensProfileEdit() throws {
        let credentials = try XCTUnwrap(
            loadTestCredentials(),
            "DOGAREA_TEST_EMAIL/DOGAREA_TEST_PASSWORD 또는 .design_audit_credentials.json이 필요합니다."
        )
        let app = launchAppForFeatureRegression()

        XCTAssertTrue(openTab(index: 4, app: app), "설정 탭 진입에 실패했습니다.")
        XCTAssertTrue(
            ensureMemberSession(app: app, credentials: credentials),
            "회원 상태 진입에 실패했습니다."
        )

        XCTAssertTrue(openTab(index: 4, app: app), "로그인 후 설정 탭 재진입에 실패했습니다.")

        let profileImageButton = app.buttons["settings.profile.image"]
        XCTAssertTrue(waitUntilExists(profileImageButton, timeout: 6), "사용자 프로필 이미지 편집 버튼을 찾지 못했습니다.")
        XCTAssertTrue(tapIfExists(profileImageButton), "사용자 프로필 이미지 탭에 실패했습니다.")

        let profileEditSheet = screenElement(identifier: "sheet.settings.profileEdit", in: app)
        XCTAssertTrue(waitUntilExists(profileEditSheet, timeout: 8), "사용자 이미지 탭 후 프로필 편집 시트를 찾지 못했습니다.")
        XCTAssertTrue(
            waitUntilExists(app.buttons["settings.profileEditor.userImage"], timeout: 4),
            "프로필 편집 시트의 사용자 이미지 탭 영역을 찾지 못했습니다."
        )
        _ = tapIfExists(app.buttons["sheet.settings.profileEdit.cancel"])

        let petImageButton = app.buttons["settings.pet.image"]
        XCTAssertTrue(waitUntilExists(petImageButton, timeout: 6), "반려견 이미지 편집 버튼을 찾지 못했습니다.")
        XCTAssertTrue(tapIfExists(petImageButton), "반려견 이미지 탭에 실패했습니다.")
        XCTAssertTrue(waitUntilExists(profileEditSheet, timeout: 8), "반려견 이미지 탭 후 프로필 편집 시트를 찾지 못했습니다.")
        XCTAssertTrue(
            waitUntilExists(app.buttons["settings.profileEditor.petImage"], timeout: 4),
            "프로필 편집 시트의 반려견 이미지 탭 영역을 찾지 못했습니다."
        )
        _ = tapIfExists(app.buttons["sheet.settings.profileEdit.cancel"])
    }

    /// 회원 상태에서 반려견 관리 시트로 기존 반려견 정보를 수정할 수 있는지 검증합니다.
    func testFeatureRegression_MemberPetManagementEditsExistingPet() throws {
        let credentials = try XCTUnwrap(
            loadTestCredentials(),
            "DOGAREA_TEST_EMAIL/DOGAREA_TEST_PASSWORD 또는 .design_audit_credentials.json이 필요합니다."
        )
        let app = launchAppForFeatureRegression(extraArguments: ["-UITest.PetManagementStub"])

        XCTAssertTrue(openTab(index: 4, app: app), "설정 탭 진입에 실패했습니다.")
        XCTAssertTrue(
            ensureMemberSession(app: app, credentials: credentials),
            "회원 상태 진입에 실패했습니다."
        )

        XCTAssertTrue(openTab(index: 4, app: app), "로그인 후 설정 탭 재진입에 실패했습니다.")
        let petManagementEntryButton = app.buttons["settings.pet.manage"]
        XCTAssertTrue(
            revealElementByVerticalScroll(petManagementEntryButton, app: app, maxSwipes: 6),
            "반려견 관리 진입 버튼을 화면 안으로 노출하지 못했습니다."
        )
        XCTAssertTrue(waitUntilHittable(petManagementEntryButton, timeout: 3), "반려견 관리 진입 버튼이 탭 가능한 상태가 아닙니다.")
        XCTAssertTrue(tapIfExists(petManagementEntryButton), "반려견 관리 시트 진입에 실패했습니다.")
        let petManagementCloseButton = app.buttons["sheet.settings.petManagement.close"]
        if waitUntilExists(petManagementCloseButton, timeout: 2) == false {
            XCTAssertTrue(tapIfExists(petManagementEntryButton), "반려견 관리 시트 재진입 탭에 실패했습니다.")
        }
        XCTAssertTrue(waitUntilExists(petManagementCloseButton, timeout: 8), "반려견 관리 시트를 찾지 못했습니다.")
        XCTAssertTrue(
            waitUntilExists(app.buttons["sheet.settings.petManagement.add"], timeout: 4),
            "반려견 관리 시트 기본 액션을 찾지 못했습니다."
        )

        let editButton = app.buttons.matching(identifier: "settings.petManagement.edit").firstMatch
        XCTAssertTrue(waitUntilExists(editButton, timeout: 12), "반려견 편집 버튼을 찾지 못했습니다.")
        XCTAssertTrue(tapIfExists(editButton), "반려견 편집 버튼 탭에 실패했습니다.")

        let editSheet = screenElement(identifier: "sheet.settings.petManagement.edit", in: app)
        XCTAssertTrue(waitUntilExists(editSheet, timeout: 8), "반려견 편집 시트를 찾지 못했습니다.")

        let petNameField = editSheet.descendants(matching: .textField)
            .matching(identifier: "settings.profile.field.petName")
            .firstMatch
        XCTAssertTrue(waitUntilExists(petNameField, timeout: 4), "반려견 이름 입력 필드를 찾지 못했습니다.")
        replaceText(on: petNameField, with: "UITestManagedDog")
        XCTAssertTrue(tapIfExists(app.buttons["sheet.settings.petManagement.edit.save"]), "반려견 편집 저장 버튼 탭에 실패했습니다.")
        if waitUntilGone(editSheet, timeout: 8) == false {
            let errorLabel = app.staticTexts["sheet.settings.petManagement.edit.error"]
            let errorMessage = waitUntilExists(errorLabel, timeout: 1)
                ? errorLabel.label
                : "none"
            XCTFail("반려견 편집 저장 후 시트가 닫히지 않았습니다. error=\(errorMessage)")
        }

        XCTAssertTrue(waitUntilExists(app.staticTexts["UITestManagedDog"], timeout: 4), "반려견 관리 시트에서 수정된 반려견 이름이 즉시 반영되지 않았습니다.")
        _ = tapIfExists(petManagementCloseButton)
    }

    /// 로그아웃 후 재로그인하고 라이벌 탭에서 익명 공유를 시작할 수 있는지 검증합니다.
    func testFeatureRegression_RivalAuthRevalidationFlow() throws {
        let credentials = try XCTUnwrap(
            loadTestCredentials(),
            "DOGAREA_TEST_EMAIL/DOGAREA_TEST_PASSWORD 또는 .design_audit_credentials.json이 필요합니다."
        )
        let app = launchAppForFeatureRegression()

        XCTAssertTrue(waitUntilExists(app.buttons["tab.4"], timeout: 12), "탭바가 렌더링되지 않았습니다.")
        XCTAssertTrue(openTab(index: 4, app: app), "설정 탭 진입에 실패했습니다.")
        performLogoutIfNeeded(app)
        XCTAssertTrue(
            signInFromAnyEntry(app: app, credentials: credentials),
            "재검증 시나리오 로그인에 실패했습니다."
        )

        XCTAssertTrue(openTab(index: 3, app: app), "라이벌 탭 진입에 실패했습니다.")
        XCTAssertTrue(waitUntilMemberState(app, timeout: 8), "로그인 세션이 라이벌 탭에 반영되지 않았습니다.")
        triggerRivalSharingStart(app)
        XCTAssertTrue(
            waitUntilExists(app.buttons["rival.sharing.stop"], timeout: 12),
            "익명 공유 시작 후 공유 중지 버튼이 나타나지 않았습니다."
        )
    }

    /// 위젯 라우트 시뮬레이션으로 라이벌 탭이 기본 딥링크 진입을 처리하는지 검증합니다.
    func testFeatureRegression_WidgetRouteOpensRivalTab() throws {
        let app = launchAppForFeatureRegression(extraArguments: ["-UITest.WidgetRoute", "open_rival_tab"])
        XCTAssertTrue(
            waitUntilExists(screenElement(identifier: "screen.rival.content", in: app), timeout: 8),
            "위젯 라우트로 라이벌 탭에 진입하지 못했습니다."
        )
    }

    /// 기능 회귀 검증용 런타임 인자로 앱을 실행합니다.
    /// - Parameters:
    ///   - style: 테스트에 적용할 인터페이스 스타일입니다.
    ///   - extraArguments: 기본 회귀 인자에 추가로 전달할 런타임 인자입니다.
    /// - Returns: 실행 완료 후 포그라운드 상태로 진입한 `XCUIApplication` 인스턴스입니다.
    private func launchAppForFeatureRegression(
        style: InterfaceStyle = .light,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UITest.FeatureRegression", "1",
            "-UITest.SkipSplash",
            "-UITest.AutoGuest",
            "-UITest.InterfaceStyle", style.rawValue
        ] + extraArguments
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 12), "앱이 foreground 상태로 실행되지 않았습니다.")
        return app
    }

    /// 이메일/비밀번호를 입력해 로그인 버튼을 누르고 화면 복귀를 기다립니다.
    /// - Parameters:
    ///   - app: 로그인 화면을 포함한 테스트 대상 앱 인스턴스입니다.
    ///   - credentials: UI 테스트에서 사용할 인증 정보입니다.
    /// - Returns: 로그인 화면이 사라지면 `true`를 반환합니다.
    private func performEmailLogin(app: XCUIApplication, credentials: TestCredentials) -> Bool {
        let emailField = app.textFields["signin.email"]
        let passwordField = app.secureTextFields["signin.password"]
        let loginButton = app.buttons["signin.login"]

        guard waitUntilExists(emailField, timeout: 5),
              waitUntilExists(passwordField, timeout: 5),
              waitUntilExists(loginButton, timeout: 5)
        else {
            return false
        }

        replaceText(on: emailField, with: credentials.email)
        replaceText(on: passwordField, with: credentials.password)
        loginButton.tap()

        return waitUntilGone(emailField, timeout: 10)
    }

    /// 설정 화면에서 현재 로그인 상태를 확인하고 필요 시 로그아웃까지 완료합니다.
    /// - Parameter app: 테스트 대상 앱 인스턴스입니다.
    private func performLogoutIfNeeded(_ app: XCUIApplication) {
        let logoutButton = app.buttons["settings.logout"]
        guard waitUntilExists(logoutButton, timeout: 3) else {
            return
        }
        logoutButton.tap()
        usleep(250_000)
        let alertLogout = app.alerts.buttons["로그아웃"].firstMatch
        if waitUntilExists(alertLogout, timeout: 3) {
            alertLogout.tap()
        }
        XCTAssertTrue(
            waitUntilExists(app.buttons["settings.open.signin"], timeout: 8),
            "로그아웃 후 로그인 진입 버튼이 나타나지 않았습니다."
        )
    }

    /// 현재 화면 상태에 맞춰 로그인 진입점을 탐색하고 이메일 로그인을 완료합니다.
    /// - Parameters:
    ///   - app: 테스트 대상 앱 인스턴스입니다.
    ///   - credentials: UI 테스트에서 사용할 인증 정보입니다.
    /// - Returns: 로그인 화면 진입 및 인증 완료 시 `true`를 반환합니다.
    private func signInFromAnyEntry(app: XCUIApplication, credentials: TestCredentials) -> Bool {
        let signInEmailField = app.textFields["signin.email"]
        if waitUntilExists(signInEmailField, timeout: 2) == false {
            if tapIfExists(app.buttons["entry.openSignIn"]) {
                usleep(250_000)
            } else if tapIfExists(app.buttons["settings.open.signin"]) {
                usleep(250_000)
                if tapIfExists(app.buttons["sheet.memberUpgrade.signin"]) {
                    usleep(300_000)
                }
            } else if tapIfExists(app.buttons["rival.login.start"]) {
                usleep(250_000)
                if tapIfExists(app.buttons["sheet.memberUpgrade.signin"]) {
                    usleep(300_000)
                }
            }
        }

        if waitUntilExists(signInEmailField, timeout: 8) == false {
            _ = tapIfExists(app.buttons["sheet.memberUpgrade.signin"])
            _ = tapIfExists(app.buttons["entry.openSignIn"])
            _ = tapIfExists(app.buttons["settings.open.signin"])
        }

        guard waitUntilExists(signInEmailField, timeout: 8) else {
            return false
        }
        let didSignIn = performEmailLogin(app: app, credentials: credentials)
        if didSignIn {
            _ = waitUntilMemberState(app, timeout: 8)
        }
        return didSignIn
    }

    /// 현재 앱 상태가 이미 회원이면 그대로 사용하고, 게스트 상태면 로그인까지 완료합니다.
    /// - Parameters:
    ///   - app: 테스트 대상 앱 인스턴스입니다.
    ///   - credentials: 로그인에 사용할 테스트 계정입니다.
    /// - Returns: 회원 상태가 확보되면 `true`를 반환합니다.
    private func ensureMemberSession(app: XCUIApplication, credentials: TestCredentials) -> Bool {
        if waitUntilExists(app.buttons["settings.logout"], timeout: 2) {
            return true
        }
        return signInFromAnyEntry(app: app, credentials: credentials)
    }

    /// 라이벌 탭에서 익명 공유 시작 플로우를 실행합니다.
    /// - Parameter app: 테스트 대상 앱 인스턴스입니다.
    private func triggerRivalSharingStart(_ app: XCUIApplication) {
        let stopButton = app.buttons["rival.sharing.stop"]
        if waitUntilExists(stopButton, timeout: 2) {
            stopButton.tap()
            usleep(600_000)
        }

        let startButton = app.buttons["rival.sharing.start"]
        XCTAssertTrue(waitUntilExists(startButton, timeout: 8), "익명 공유 시작 버튼을 찾지 못했습니다.")
        startButton.tap()
        usleep(300_000)

        handleLocationPermissionAlertIfNeeded()

        let consentConfirmButton = app.buttons["sheet.rival.consent.confirm"]
        if waitUntilExists(consentConfirmButton, timeout: 5) {
            consentConfirmButton.tap()
            usleep(300_000)
            return
        }

        if waitUntilExists(startButton, timeout: 3) {
            startButton.tap()
            usleep(300_000)
            handleLocationPermissionAlertIfNeeded()
            if waitUntilExists(consentConfirmButton, timeout: 5) {
                consentConfirmButton.tap()
                usleep(300_000)
            }
        }
    }

    /// 지도 탭의 산책 시작/종료 주행동을 접근성 트리 타입과 무관하게 조회합니다.
    /// - Parameter app: 테스트 대상 앱 인스턴스입니다.
    /// - Returns: `"map.walk.primaryAction"` 식별자를 우선 사용하고, 필요 시 `"map.bottomControls"`로 fallback한 첫 번째 접근성 요소입니다.
    private func mapPrimaryAction(in app: XCUIApplication) -> XCUIElement {
        let primaryAction = app.descendants(matching: .any)
            .matching(identifier: "map.walk.primaryAction")
            .firstMatch
        if primaryAction.exists {
            return primaryAction
        }

        let bottomControls = app.buttons["map.bottomControls"]
        if bottomControls.exists {
            return bottomControls
        }

        return primaryAction
    }

    /// 접근성 타입과 무관하게 화면 식별자에 대응하는 첫 번째 요소를 조회합니다.
    /// - Parameters:
    ///   - identifier: 찾을 화면 접근성 식별자입니다.
    ///   - app: 테스트 대상 앱 인스턴스입니다.
    /// - Returns: 지정한 식별자와 일치하는 첫 번째 접근성 요소입니다.
    private func screenElement(identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    /// 지도 탭 접근성 후보를 출력해 시작 버튼 누락 원인을 추적합니다.
    /// - Parameter app: 현재 접근성 트리를 덤프할 테스트 대상 앱 인스턴스입니다.
    private func dumpMapAccessibilityCandidates(_ app: XCUIApplication) {
        let buttonSummaries = app.descendants(matching: .button).allElementsBoundByIndex.map {
            "button id='\($0.identifier)' label='\($0.label)' value='\(String(describing: $0.value))'"
        }
        let otherSummaries = app.descendants(matching: .other).allElementsBoundByIndex
            .filter { $0.identifier.isEmpty == false }
            .map { "other id='\($0.identifier)' label='\($0.label)'" }

        print("[FeatureRegressionUITests][MapAccessibility][Buttons]")
        print(buttonSummaries.joined(separator: "\n"))
        print("[FeatureRegressionUITests][MapAccessibility][Other]")
        print(otherSummaries.joined(separator: "\n"))
    }

    /// 영역 목표 상세 진입 실패 시 관련 접근성 후보를 출력해 실제 라우팅 상태를 추적합니다.
    /// - Parameter app: 현재 접근성 트리를 덤프할 테스트 대상 앱 인스턴스입니다.
    private func dumpTerritoryGoalAccessibilityCandidates(_ app: XCUIApplication) {
        let buttonSummaries = app.descendants(matching: .button).allElementsBoundByIndex
            .filter { element in
                element.identifier.isEmpty == false ||
                element.label.contains("영역") ||
                element.label.contains("목표") ||
                element.label.contains("비교")
            }
            .map { "button id='\($0.identifier)' label='\($0.label)'" }
        let textSummaries = app.descendants(matching: .staticText).allElementsBoundByIndex
            .filter { element in
                element.identifier.isEmpty == false ||
                element.label.contains("영역") ||
                element.label.contains("목표") ||
                element.label.contains("나무")
            }
            .map { "text id='\($0.identifier)' label='\($0.label)'" }
        let otherSummaries = app.descendants(matching: .other).allElementsBoundByIndex
            .filter { $0.identifier.isEmpty == false }
            .map { "other id='\($0.identifier)' label='\($0.label)'" }

        print("[FeatureRegressionUITests][TerritoryGoalAccessibility][Buttons]")
        print(buttonSummaries.joined(separator: "\n"))
        print("[FeatureRegressionUITests][TerritoryGoalAccessibility][Texts]")
        print(textSummaries.joined(separator: "\n"))
        print("[FeatureRegressionUITests][TerritoryGoalAccessibility][Other]")
        print(otherSummaries.joined(separator: "\n"))
    }

    /// 지도 탭이 인증 일시중단 상태를 벗어나 실제 콘텐츠 화면으로 전환될 때까지 대기합니다.
    /// - Parameters:
    ///   - app: 테스트 대상 앱 인스턴스입니다.
    ///   - timeout: 지도 준비 완료를 기다릴 최대 시간입니다.
    /// - Returns: 지도 콘텐츠 화면이 준비되면 `true`를 반환합니다.
    private func waitUntilMapReady(_ app: XCUIApplication, timeout: TimeInterval = 12) -> Bool {
        let suspendedMap = screenElement(identifier: "screen.map.suspended", in: app)
        let readyMap = screenElement(identifier: "screen.map", in: app)
        _ = waitUntilGone(suspendedMap, timeout: 6)
        return waitUntilExists(readyMap, timeout: timeout)
    }

    /// 위치 권한 시스템 알림이 표시되면 허용 버튼을 탭합니다.
    private func handleLocationPermissionAlertIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowCandidates = [
            "앱을 사용하는 동안 허용",
            "허용",
            "Allow While Using App",
            "Allow Once",
            "Allow"
        ]
        for title in allowCandidates {
            let button = springboard.buttons[title]
            if waitUntilExists(button, timeout: 1.2) {
                button.tap()
                usleep(300_000)
                return
            }
        }
    }

    /// 테스트 프로세스 환경변수에서 이메일 로그인용 계정을 로드합니다.
    /// - Returns: 환경변수나 프로젝트 루트 credentials 파일에서 찾은 인증 정보입니다.
    private func loadTestCredentials() -> TestCredentials? {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["DOGAREA_TEST_EMAIL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = env["DOGAREA_TEST_PASSWORD"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              email.isEmpty == false,
              password.isEmpty == false
        else {
            return loadTestCredentialsFromProjectFile()
        }
        return TestCredentials(email: email, password: password)
    }

    /// UI 테스트 실행 스크립트가 생성한 임시 credentials 파일을 읽습니다.
    /// - Returns: 프로젝트 루트 credentials 파일이 유효하면 인증 정보를 반환합니다.
    private func loadTestCredentialsFromProjectFile() -> TestCredentials? {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let credentialsFileURL = projectRoot.appendingPathComponent(".design_audit_credentials.json")
        guard let data = try? Data(contentsOf: credentialsFileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = object["email"] as? String,
              let password = object["password"] as? String
        else {
            return nil
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.isEmpty == false, normalizedPassword.isEmpty == false else {
            return nil
        }
        return TestCredentials(email: normalizedEmail, password: normalizedPassword)
    }

    /// 로그인 화면이 시트/엔트리 선택 단계를 거쳐 표시되는 경우 필요한 중간 CTA를 순차적으로 처리합니다.
    /// - Parameter app: 로그인 진입 흐름을 처리할 테스트 대상 앱 인스턴스입니다.
    /// - Returns: 로그인 화면 또는 로그인 진입 버튼이 노출될 때까지 중간 단계를 처리한 경우 `true`를 반환합니다.
    @discardableResult
    private func presentSignInFlowIfNeeded(_ app: XCUIApplication) -> Bool {
        if waitUntilExists(screenElement(identifier: "screen.signin", in: app), timeout: 1.2) {
            return true
        }

        let memberUpgradeSignInButton = app.buttons["sheet.memberUpgrade.signin"]
        if waitUntilExists(memberUpgradeSignInButton, timeout: 2.5) {
            memberUpgradeSignInButton.tap()
            usleep(300_000)
        }

        if waitUntilExists(screenElement(identifier: "screen.signin", in: app), timeout: 1.2) {
            return true
        }

        let entrySignInButton = app.buttons["entry.openSignIn"]
        if waitUntilExists(entrySignInButton, timeout: 2.5) {
            entrySignInButton.tap()
            usleep(300_000)
        }

        return waitUntilExists(screenElement(identifier: "screen.signin", in: app), timeout: 2.5)
    }

    /// 커스텀 탭 인덱스로 탭 전환을 시도합니다.
    /// - Parameters:
    ///   - index: 전환할 탭 인덱스입니다.
    ///   - app: 테스트 대상 앱 인스턴스입니다.
    /// - Returns: 탭 버튼을 찾고 탭 전환에 성공하면 `true`를 반환합니다.
    private func openTab(index: Int, app: XCUIApplication) -> Bool {
        let button = app.buttons["tab.\(index)"]
        if waitUntilExists(button, timeout: 12) == false {
            let continueAsGuest = app.buttons["entry.continueGuest"].firstMatch
            if continueAsGuest.exists {
                continueAsGuest.tap()
                usleep(300_000)
            }
        }
        guard waitUntilExists(button, timeout: 12) else {
            return false
        }
        button.tap()
        usleep(350_000)
        return true
    }

    /// 세로 스크롤을 반복해 대상 요소가 화면에 노출될 때까지 탐색합니다.
    /// - Parameters:
    ///   - element: 노출될 때까지 탐색할 대상 요소입니다.
    ///   - app: 스와이프 제스처를 전달할 앱 인스턴스입니다.
    ///   - maxSwipes: 최대 스와이프 횟수입니다.
    /// - Returns: 제한 횟수 내 요소가 노출되면 `true`, 아니면 `false`입니다.
    private func revealElementByVerticalScroll(
        _ element: XCUIElement,
        app: XCUIApplication,
        maxSwipes: Int
    ) -> Bool {
        if element.exists && element.isHittable { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            usleep(260_000)
            if element.exists && element.isHittable { return true }
        }
        return element.exists && element.isHittable
    }

    /// 세로 스크롤을 반복해 대상 요소가 접근성 트리에 나타날 때까지 탐색합니다.
    /// - Parameters:
    ///   - element: 존재 여부를 기준으로 탐색할 대상 요소입니다.
    ///   - app: 스와이프 제스처를 전달할 앱 인스턴스입니다.
    ///   - maxSwipes: 최대 스와이프 횟수입니다.
    /// - Returns: 제한 횟수 내 요소가 존재하면 `true`, 아니면 `false`입니다.
    private func revealExistingElementByVerticalScroll(
        _ element: XCUIElement,
        app: XCUIApplication,
        maxSwipes: Int
    ) -> Bool {
        if element.exists { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            usleep(260_000)
            if element.exists { return true }
        }
        return element.exists
    }

    /// 가능한 경우 단일 탭 동작을 수행하고 성공 여부를 반환합니다.
    /// - Parameter element: 탭을 시도할 대상 요소입니다.
    /// - Returns: 요소가 존재하고 직접 탭 또는 좌표 탭에 성공하면 `true`를 반환합니다.
    @discardableResult
    private func tapIfExists(_ element: XCUIElement) -> Bool {
        guard waitUntilExists(element, timeout: 1.5) else { return false }
        if element.isHittable {
            element.tap()
            usleep(250_000)
            return true
        }

        let frame = element.frame
        guard frame.isEmpty == false else { return false }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        usleep(250_000)
        return true
    }

    /// UI 요소가 지정 시간 내에 화면에 나타나는지 대기합니다.
    /// - Parameters:
    ///   - element: 존재 여부를 확인할 UI 요소입니다.
    ///   - timeout: 대기 최대 시간(초)입니다.
    /// - Returns: 시간 내 요소가 나타나면 `true`, 아니면 `false`입니다.
    private func waitUntilExists(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// UI 요소가 지정 시간 내에 탭 가능한 상태로 안정화되는지 대기합니다.
    /// - Parameters:
    ///   - element: 탭 가능 여부를 확인할 UI 요소입니다.
    ///   - timeout: 최대 대기 시간(초)입니다.
    /// - Returns: 시간 내 요소가 존재하고 `isHittable == true`가 되면 `true`를 반환합니다.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                usleep(180_000)
                return true
            }
            usleep(120_000)
        }
        return element.exists && element.isHittable
    }

    /// UI 요소가 지정 시간 내에 화면에서 사라지는지 대기합니다.
    /// - Parameters:
    ///   - element: 사라짐 여부를 확인할 UI 요소입니다.
    ///   - timeout: 대기 최대 시간(초)입니다.
    /// - Returns: 시간 내 요소가 사라지면 `true`, 아니면 `false`입니다.
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// 로그인 성공 후 회원 상태 UI 표식이 등장하는지 대기합니다.
    /// - Parameters:
    ///   - app: 테스트 대상 앱 인스턴스입니다.
    ///   - timeout: 최대 대기 시간입니다.
    /// - Returns: 회원 상태 UI 표식이 나타나면 `true`를 반환합니다.
    private func waitUntilMemberState(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.buttons["rival.sharing.start"].exists || app.buttons["rival.sharing.stop"].exists {
                return true
            }
            if app.buttons["settings.profile.edit"].exists {
                return true
            }
            usleep(120_000)
        }
        return false
    }

    /// 텍스트 입력 필드를 초기화하고 새 값을 입력합니다.
    /// - Parameters:
    ///   - element: 값을 교체할 텍스트 입력 요소입니다.
    ///   - value: 새로 입력할 문자열입니다.
    private func replaceText(on element: XCUIElement, with value: String) {
        element.tap()
        if let currentValue = element.value as? String,
           currentValue.isEmpty == false,
           currentValue != value,
           currentValue.contains("이메일") == false,
           currentValue.contains("비밀번호") == false {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            element.typeText(deleteString)
        }
        element.typeText(value)
    }

    /// 최상단 모달을 닫기 위해 버튼 탭 또는 스와이프를 시도합니다.
    /// - Parameter app: 테스트 대상 앱 인스턴스입니다.
    private func dismissTopModalIfNeeded(_ app: XCUIApplication) {
        let closeCandidates = ["닫기", "취소", "완료", "나중에", "Close", "Done"]
        for title in closeCandidates {
            let button = app.buttons[title]
            if button.exists {
                button.tap()
                usleep(250_000)
                return
            }
        }

        let sheet = app.sheets.firstMatch
        if sheet.exists {
            sheet.swipeDown()
            usleep(250_000)
        }
    }

    /// 네비게이션 스택이 존재하면 뒤로 이동을 시도합니다.
    /// - Parameter app: 테스트 대상 앱 인스턴스입니다.
    private func navigateBackIfPossible(_ app: XCUIApplication) {
        let candidates = ["뒤로", "Back", "산책 목록", "홈"]
        for title in candidates {
            let backButton = app.navigationBars.buttons[title]
            if backButton.exists {
                backButton.tap()
                usleep(250_000)
                return
            }
        }

        let firstBack = app.navigationBars.buttons.firstMatch
        if firstBack.exists {
            firstBack.tap()
            usleep(250_000)
        }
    }
}
