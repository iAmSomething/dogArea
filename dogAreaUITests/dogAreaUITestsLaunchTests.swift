import XCTest

/// UI 테스트 타겟의 기본 런치 검증용 테스트입니다.
final class dogAreaUITestsLaunchTests: XCTestCase {
    /// 런치 후 기본 스냅샷을 남겨 앱 부팅 여부를 확인합니다.
    func testLaunchSnapshot() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
