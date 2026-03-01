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

    /// 가능한 경우 단일 탭 동작을 수행하고 성공 여부를 반환합니다.
    @discardableResult
    private func tapIfExists(_ element: XCUIElement) -> Bool {
        guard waitUntilExists(element, timeout: 1.5) else { return false }
        element.tap()
        usleep(250_000)
        return true
    }

    /// `waitForExistence`의 디버그 덤프 정체를 피하기 위해 단순 폴링으로 존재 여부를 확인합니다.
    private func waitUntilExists(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return true }
            usleep(120_000)
        }
        return element.exists
    }

    /// 요소가 화면에서 사라질 때까지 폴링합니다.
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists == false { return true }
            usleep(120_000)
        }
        return element.exists == false
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
