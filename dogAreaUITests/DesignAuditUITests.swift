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

        let goalMoreButton = app.buttons["home.goalTracker.more"]
        if revealElementByVerticalScroll(goalMoreButton, app: app, maxSwipes: 8),
           tapIfExists(goalMoreButton),
           screenElement(identifier: "screen.territoryGoal", in: app).waitForExistence(timeout: 4) {
            capture(name: "001_Home_TerritoryGoal", outputDirectory: outputDirectory)

            let catalogButton = app.buttons["territory.goal.catalog"]
            if tapIfExists(catalogButton),
               screenElement(identifier: "screen.areaDetail", in: app).waitForExistence(timeout: 4) {
                capture(name: "001_Home_AreaDetailCatalog", outputDirectory: outputDirectory)
                navigateBackIfPossible(app)
            }

            navigateBackIfPossible(app)
        }

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
            XCTAssertTrue(screenElement(identifier: "sheet.map.settings", in: app).waitForExistence(timeout: 3))
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
                _ = presentSignInFlowIfNeeded(app)
                if screenElement(identifier: "screen.signin", in: app).waitForExistence(timeout: 3) {
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
            if screenElement(identifier: "sheet.settings.profileEdit", in: app).waitForExistence(timeout: 3) {
                capture(name: "005_Settings_ProfileEdit", outputDirectory: outputDirectory)
            }
            _ = tapIfExists(app.buttons["sheet.settings.profileEdit.cancel"])
            dismissTopModalIfNeeded(app)
        }

        if signedInAsMember, tapIfExists(app.buttons["settings.pet.manage"]) {
            if screenElement(identifier: "sheet.settings.petManagement", in: app).waitForExistence(timeout: 3) {
                capture(name: "005_Settings_PetManagement", outputDirectory: outputDirectory)
            }

            let editButton = app.buttons.matching(identifier: "settings.petManagement.edit").firstMatch
            if tapIfExists(editButton) {
                if screenElement(identifier: "sheet.settings.petManagement.edit", in: app).waitForExistence(timeout: 3) {
                    capture(name: "005_Settings_PetManagement_Edit", outputDirectory: outputDirectory)
                }
                _ = tapIfExists(app.buttons["sheet.settings.petManagement.edit.cancel"])
                dismissTopModalIfNeeded(app)
            }

            _ = tapIfExists(app.buttons["sheet.settings.petManagement.close"])
            dismissTopModalIfNeeded(app)
        }

        if tapIfExists(app.buttons["settings.open.signin"]) {
            _ = presentSignInFlowIfNeeded(app)
            if screenElement(identifier: "screen.signin", in: app).waitForExistence(timeout: 3) {
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

    /// 인증 재검증 시나리오용 런타임 인자로 앱을 실행합니다.
    /// - Parameter style: 테스트에 적용할 인터페이스 스타일입니다.
    /// - Returns: 실행 완료 후 포그라운드 상태로 진입한 `XCUIApplication` 인스턴스입니다.
    private func launchAppForAuthRevalidation(style: InterfaceStyle = .light) -> XCUIApplication {
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

    /// 로그인 화면이 시트/엔트리 선택 단계를 거쳐 표시되는 경우 필요한 중간 CTA를 순차적으로 처리합니다.
    /// - Parameter app: 로그인 진입 흐름을 처리할 테스트 대상 앱 인스턴스입니다.
    /// - Returns: 로그인 화면 또는 로그인 진입 버튼이 노출될 때까지 중간 단계를 처리한 경우 `true`를 반환합니다.
    @discardableResult
    private func presentSignInFlowIfNeeded(_ app: XCUIApplication) -> Bool {
        if screenElement(identifier: "screen.signin", in: app).waitForExistence(timeout: 1.2) {
            return true
        }

        let memberUpgradeSignInButton = app.buttons["sheet.memberUpgrade.signin"]
        if memberUpgradeSignInButton.waitForExistence(timeout: 2.5) {
            memberUpgradeSignInButton.tap()
            usleep(300_000)
        }

        if screenElement(identifier: "screen.signin", in: app).waitForExistence(timeout: 1.2) {
            return true
        }

        let entrySignInButton = app.buttons["entry.openSignIn"]
        if entrySignInButton.waitForExistence(timeout: 2.5) {
            entrySignInButton.tap()
            usleep(300_000)
        }

        return screenElement(identifier: "screen.signin", in: app).waitForExistence(timeout: 2.5)
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
    ///   - credentials: 재검증에 사용할 테스트 계정 정보입니다.
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

    /// 로그인 플로우 보조 캡처용 임시 디렉터리를 생성합니다.
    /// - Returns: 스크린샷 저장 가능한 임시 URL 경로입니다.
    private func makeTemporaryAuditOutputDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dogarea-auth-revalidation", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
        guard element.isHittable else { return false }
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
