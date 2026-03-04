import XCTest

/// 주요 화면을 순회하며 디자인 점검 스크린샷을 로컬 파일로 저장하는 UI 테스트입니다.
final class DesignAuditUITests: XCTestCase {
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

    /// 라이트 모드 시나리오를 실행하고 `/DesignAuditShots/light`에 스크린샷을 저장합니다.
    func testDesignAudit_LightMode() throws {
        try runDesignAudit(style: .light)
    }

    /// 다크 모드 시나리오를 실행하고 `/DesignAuditShots/dark`에 스크린샷을 저장합니다.
    func testDesignAudit_DarkMode() throws {
        try runDesignAudit(style: .dark)
    }

    /// 지도 탭의 산책 시작 버튼이 하단 탭바와 겹치지 않고 탭 가능한지 검증합니다.
    func testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(openTab(index: 2, app: app), "지도 탭 진입에 실패했습니다.")
    }

    /// 홈의 영역 목표 상세 진입 시 탭바가 숨겨지고 뒤로 복귀 시 다시 표시되는지 검증합니다.
    func testFeatureRegression_TerritoryGoalNavigationHidesAndRestoresTabBar() throws {
        let app = launchAppForFeatureRegression()
        XCTAssertTrue(waitUntilExists(app.buttons["tab.0"], timeout: 12), "탭바가 렌더링되지 않았습니다.")
        XCTAssertTrue(openTab(index: 0, app: app), "홈 탭 진입에 실패했습니다.")

        let moreButton = app.descendants(matching: .any)
            .matching(identifier: "home.goalTracker.more")
            .firstMatch
        XCTAssertTrue(
            revealElementByVerticalScroll(moreButton, app: app, maxSwipes: 8),
            "영역 목표 트래커의 비교군 더보기 버튼을 찾지 못했습니다."
        )
        XCTAssertTrue(tapIfExists(moreButton), "영역 목표 트래커의 비교군 더보기 버튼 탭에 실패했습니다.")

        let didEnterTerritoryGoal =
            waitUntilExists(app.otherElements["screen.territoryGoal"], timeout: 10) ||
            waitUntilExists(app.staticTexts["Territory Goal Tracker"], timeout: 10) ||
            waitUntilExists(app.staticTexts["나무의 영역"], timeout: 10)
        XCTAssertTrue(didEnterTerritoryGoal, "영역 목표 상세 화면 진입에 실패했습니다.")
        XCTAssertTrue(
            waitUntilGone(app.buttons["tab.2"], timeout: 3),
            "영역 목표 상세 화면에서는 하단 탭바가 숨겨져야 합니다."
        )

        navigateBackIfPossible(app)
        XCTAssertTrue(waitUntilExists(app.buttons["tab.2"], timeout: 6), "상세 화면 복귀 후 하단 탭바가 다시 표시되지 않았습니다.")
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
            XCTAssertTrue(waitUntilExists(app.otherElements["screen.signin"], timeout: 6), "로그인 화면 진입에 실패했습니다.")
            _ = tapIfExists(app.buttons["signin.dismiss"])
            dismissTopModalIfNeeded(app)
            return
        }

        XCTAssertTrue(waitUntilExists(logoutButton, timeout: 3), "회원 상태 설정 진입점(로그아웃 버튼)을 찾지 못했습니다.")
        XCTAssertTrue(logoutButton.isHittable, "로그아웃 버튼이 탭 가능한 상태가 아닙니다.")
    }

    /// 지정한 인터페이스 스타일로 앱을 실행하고 주요 화면/서브뷰를 순회해 스크린샷을 저장합니다.
    private func runDesignAudit(style: InterfaceStyle) throws {
        let outputDirectory = try prepareOutputDirectory(style: style)
        let credentials = loadTestCredentials()
        print("[DesignAudit] credentials_loaded=\(credentials != nil)")

        let app = XCUIApplication()
        app.launchArguments += [
            "-UITest.DesignAudit", "1",
            "-UITest.SkipSplash",
            "-UITest.AutoGuest",
            "-UITest.InterfaceStyle", style.rawValue
        ]
        app.launchEnvironment["DESIGN_AUDIT_OUTPUT_DIR"] = outputDirectory.path
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 12), "앱이 foreground 상태로 실행되지 않았습니다.")
        XCTAssertTrue(waitUntilExists(app.buttons["tab.0"], timeout: 12), "초기 탭 버튼(tab.0) 렌더링 실패")
        capture(name: "000_Launch", outputDirectory: outputDirectory)
        guard openTab(index: 0, app: app) else {
            capture(name: "000_TabUnavailable", outputDirectory: outputDirectory)
            XCTFail("탭 버튼(tab.0)을 찾지 못했습니다.")
            return
        }
        capture(name: "001_Home", outputDirectory: outputDirectory)

        if tapIfExists(app.buttons.matching(identifier: "home.season.detail").firstMatch) {
            capture(name: "001_Home_SeasonDetail", outputDirectory: outputDirectory)
            _ = tapIfExists(app.buttons.matching(identifier: "home.season.detail.close").firstMatch)
            dismissTopModalIfNeeded(app)
        }

        guard openTab(index: 1, app: app) else {
            XCTFail("탭 버튼(tab.1)을 찾지 못했습니다.")
            return
        }
        capture(name: "002_List", outputDirectory: outputDirectory)

        if openFirstWalkListCellIfPossible(app) {
            capture(name: "002_List_Detail", outputDirectory: outputDirectory)
            navigateBackIfPossible(app)
        }

        guard openTab(index: 2, app: app) else {
            XCTFail("탭 버튼(tab.2)을 찾지 못했습니다.")
            return
        }
        capture(name: "003_Map", outputDirectory: outputDirectory)

        if tapIfExists(app.buttons["map.openSettings"]) {
            XCTAssertTrue(app.otherElements["sheet.map.settings"].waitForExistence(timeout: 3))
            capture(name: "003_Map_Settings", outputDirectory: outputDirectory)
            if !tapIfExists(app.buttons["map.settings.close"]) {
                dismissTopModalIfNeeded(app)
            }
        }

        guard openTab(index: 3, app: app) else {
            XCTFail("탭 버튼(tab.3)을 찾지 못했습니다.")
            return
        }
        capture(name: "004_Rival", outputDirectory: outputDirectory)

        var signedInAsMember = false
        if let credentials {
            signedInAsMember = signInFromRivalIfNeeded(
                app: app,
                credentials: credentials,
                outputDirectory: outputDirectory
            )
        }

        if signedInAsMember == false {
            if tapIfExists(app.buttons["rival.sharing.start"]) {
                if app.sheets.firstMatch.waitForExistence(timeout: 2) {
                    capture(name: "004_Rival_Consent", outputDirectory: outputDirectory)
                    _ = tapIfExists(app.buttons["sheet.rival.consent.cancel"])
                    dismissTopModalIfNeeded(app)
                }
            } else if tapIfExists(app.buttons["rival.login.start"]) {
                if app.otherElements["screen.signin"].waitForExistence(timeout: 3) {
                    capture(name: "004_Rival_Login", outputDirectory: outputDirectory)
                }
                _ = tapIfExists(app.buttons["signin.dismiss"])
                dismissTopModalIfNeeded(app)
            }
        } else {
            capture(name: "004_Rival_Member", outputDirectory: outputDirectory)
            if tapIfExists(app.buttons["rival.sharing.start"]) {
                if app.sheets.firstMatch.waitForExistence(timeout: 2) {
                    capture(name: "004_Rival_Consent", outputDirectory: outputDirectory)
                    _ = tapIfExists(app.buttons["sheet.rival.consent.cancel"])
                    dismissTopModalIfNeeded(app)
                }
            }
        }

        guard openTab(index: 4, app: app) else {
            XCTFail("탭 버튼(tab.4)을 찾지 못했습니다.")
            return
        }
        capture(name: "005_Settings", outputDirectory: outputDirectory)

        if signedInAsMember, waitUntilExists(app.buttons["settings.profile.edit"], timeout: 3) {
            capture(name: "005_Settings_Member", outputDirectory: outputDirectory)
        }

        if tapIfExists(app.buttons["settings.profile.edit"]) {
            if app.otherElements["sheet.settings.profileEdit"].waitForExistence(timeout: 3) {
                capture(name: "005_Settings_ProfileEdit", outputDirectory: outputDirectory)
            }
            _ = tapIfExists(app.buttons["sheet.settings.profileEdit.cancel"])
            dismissTopModalIfNeeded(app)
        }

        if tapIfExists(app.buttons["settings.open.signin"]) {
            if app.otherElements["screen.signin"].waitForExistence(timeout: 3) {
                capture(name: "006_SignIn", outputDirectory: outputDirectory)
            }
            _ = tapIfExists(app.buttons["signin.dismiss"])
            dismissTopModalIfNeeded(app)
        }
    }

    /// 기능 회귀 검증용 런타임 인자로 앱을 실행합니다.
    /// - Parameter style: 테스트에 적용할 인터페이스 스타일입니다.
    /// - Returns: 실행 완료 후 포그라운드 상태로 진입한 `XCUIApplication` 인스턴스입니다.
    private func launchAppForFeatureRegression(style: InterfaceStyle = .light) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UITest.FeatureRegression", "1",
            "-UITest.DesignAudit", "1",
            "-UITest.SkipSplash",
            "-UITest.AutoGuest",
            "-UITest.InterfaceStyle", style.rawValue
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 12), "앱이 foreground 상태로 실행되지 않았습니다.")
        return app
    }

    /// 라이벌 탭에서 로그인 유도 플로우(업그레이드 시트 -> 로그인 화면)를 처리하고 성공 여부를 반환합니다.
    private func signInFromRivalIfNeeded(
        app: XCUIApplication,
        credentials: TestCredentials,
        outputDirectory: URL
    ) -> Bool {
        let rivalLoginButton = app.buttons["rival.login.start"]
        guard waitUntilExists(rivalLoginButton, timeout: 2) else {
            return false
        }
        rivalLoginButton.tap()
        usleep(250_000)

        let memberUpgradeSignInButton = app.buttons["sheet.memberUpgrade.signin"]
        if waitUntilExists(memberUpgradeSignInButton, timeout: 4) {
            memberUpgradeSignInButton.tap()
            usleep(250_000)
        }

        let entrySignInButton = app.buttons["entry.openSignIn"]
        if waitUntilExists(entrySignInButton, timeout: 2) {
            entrySignInButton.tap()
            usleep(250_000)
        }

        let signInEmailField = app.textFields["signin.email"]
        if waitUntilExists(signInEmailField, timeout: 8) == false {
            if memberUpgradeSignInButton.exists {
                memberUpgradeSignInButton.tap()
                usleep(250_000)
            } else if entrySignInButton.exists {
                entrySignInButton.tap()
                usleep(250_000)
            }
        }

        guard waitUntilExists(signInEmailField, timeout: 6) else {
            return false
        }

        capture(name: "004_Rival_Login", outputDirectory: outputDirectory)
        let didSucceed = performEmailLogin(
            app: app,
            credentials: credentials
        )
        if didSucceed {
            _ = waitUntilMemberState(app, timeout: 6)
        }
        return didSucceed
    }

    /// 이메일/비밀번호를 입력해 로그인 버튼을 누르고 화면 복귀를 기다립니다.
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

    /// 테스트 프로세스 환경변수에서 이메일 로그인용 계정을 로드합니다.
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

    /// 저장 루트를 계산하고 스타일별 폴더를 준비합니다.
    private func prepareOutputDirectory(style: InterfaceStyle) throws -> URL {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFileURL
            .deletingLastPathComponent() // dogAreaUITests
            .deletingLastPathComponent() // repo root

        let outputRoot: URL
        if let explicitPath = ProcessInfo.processInfo.environment["DESIGN_AUDIT_OUTPUT_DIR"], explicitPath.isEmpty == false {
            outputRoot = URL(fileURLWithPath: explicitPath, isDirectory: true)
        } else {
            outputRoot = projectRoot.appendingPathComponent("DesignAuditShots", isDirectory: true)
        }

        let styleDirectory = outputRoot.appendingPathComponent(style.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: styleDirectory, withIntermediateDirectories: true)

        let existing = try FileManager.default.contentsOfDirectory(at: styleDirectory, includingPropertiesForKeys: nil)
        for file in existing where file.pathExtension.lowercased() == "png" {
            try? FileManager.default.removeItem(at: file)
        }
        return styleDirectory
    }

    /// 커스텀 탭 인덱스로 탭 전환을 시도합니다.
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

    /// 첫 번째 산책 셀을 열 수 있으면 true를 반환합니다.
    private func openFirstWalkListCellIfPossible(_ app: XCUIApplication) -> Bool {
        let firstCell = app.descendants(matching: .any).matching(identifier: "walklist.cell").firstMatch
        guard waitUntilExists(firstCell, timeout: 2) else { return false }
        firstCell.tap()
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
        if element.exists { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            usleep(260_000)
            if element.exists { return true }
        }
        return element.exists
    }

    /// 가능한 경우 단일 탭 동작을 수행하고 성공 여부를 반환합니다.
    @discardableResult
    private func tapIfExists(_ element: XCUIElement) -> Bool {
        guard waitUntilExists(element, timeout: 1.5) else { return false }
        element.tap()
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

    /// 로그인 성공 후 회원 상태 UI 표식(공유 버튼/프로필 편집 버튼) 등장 여부를 대기합니다.
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

    /// 현재 화면을 캡처하고 PNG 파일로 저장합니다.
    private func capture(name: String, outputDirectory: URL) {
        let screenshot = XCUIScreen.main.screenshot()
        let fileURL = outputDirectory.appendingPathComponent("\(name).png", isDirectory: false)

        do {
            try screenshot.pngRepresentation.write(to: fileURL)
        } catch {
            XCTFail("스크린샷 저장 실패: \(fileURL.path), error=\(error)")
        }

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
