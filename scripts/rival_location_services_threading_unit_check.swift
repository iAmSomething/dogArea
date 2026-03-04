import Foundation

/// 조건이 거짓이면 표준 에러로 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 오류 메시지입니다.
/// - Returns: 없음. 실패 시 즉시 종료합니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 파일 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let viewModel = load("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(!viewModel.contains("CLLocationManager.locationServicesEnabled()"), "RivalTabViewModel should avoid locationServicesEnabled on main thread")
assertTrue(viewModel.contains("func start()"), "RivalTabViewModel should define start()")
assertTrue(viewModel.contains("switch locationManager.authorizationStatus"), "start() should branch by authorizationStatus")
assertTrue(viewModel.contains("func locationManagerDidChangeAuthorization(_ manager: CLLocationManager)"), "RivalTabViewModel should handle authorization callback")
assertTrue(viewModel.contains("manager.startUpdatingLocation()"), "authorization callback should start location updates when authorized")
assertTrue(viewModel.contains("manager.stopUpdatingLocation()"), "authorization callback should stop location updates when unauthorized")
assertTrue(prCheck.contains("scripts/rival_location_services_threading_unit_check.swift"), "ios_pr_check should include rival location threading check")

print("PASS: rival location services threading unit checks")
