import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let signInView = load("dogArea/Views/SigningView/SignInView.swift")
let startModalView = load("dogArea/Views/MapView/StartModalView.swift")
let userDefaultsSource = load("dogArea/Source/UserdefaultSetting.swift")
let titleTextView = load("dogArea/Views/GlobalViews/TitleTextView.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let homeViewModel = load("dogArea/Views/HomeView/HomeViewModel.swift")
let walkListDetailView = load("dogArea/Views/WalkListView/WalkListDetailView.swift")
let areaMeters = load("dogArea/Views/HomeView/AreaMeters.swift")
let mapCapture = load("dogArea/Views/MapView/MapSubViews/MapCapture.swift")
let viewUtility = load("dogArea/Source/ViewUtility.swift")
let timeCheckable = load("dogArea/Source/TimeCheckable.swift")
let calendarView = load("dogArea/Views/HomeView/HomeSubView/Calender.swift")

assertTrue(!signInView.contains("identityToken!"), "SignInView should not force unwrap identityToken")
assertTrue(!signInView.contains("authorizationCode!"), "SignInView should not force unwrap authorizationCode")
assertTrue(signInView.contains("guard let identityTokenData"), "SignInView should guard identity token")

assertTrue(startModalView.contains("@State private var countdownTimer"), "StartModalView should keep timer state")
assertTrue(startModalView.contains(".onDisappear"), "StartModalView should handle disappear lifecycle")
assertTrue(startModalView.contains("invalidateCountdown()"), "StartModalView should invalidate timer")

assertTrue(!userDefaultsSource.contains("try! JSONDecoder"), "UserdefaultSetting decode should avoid try!")
assertTrue(!titleTextView.contains("subTitle!"), "TitleTextView should avoid subtitle force unwrap")
assertTrue(!homeView.contains("userInfo!"), "HomeView should avoid force unwrap userInfo")
assertTrue(
    !homeViewModel.contains("date(bySettingHour: 0, minute: 0, second: 0, of: $0)!"),
    "HomeViewModel walkedDates should avoid force unwrap date rounding"
)
assertTrue(!walkListDetailView.contains("polygon!"), "WalkListDetailView should avoid force unwrap polygon")
assertTrue(!areaMeters.contains("since!"), "AreaMeters should avoid force unwrap optional since")
assertTrue(!mapCapture.contains("UIGraphicsGetCurrentContext()!"), "MapCapture should avoid force unwrap graphics context")
assertTrue(!viewUtility.contains("UIImage(systemName: \"exclamationmark.triangle.fill\")!"), "ViewUtility should avoid force unwrap system image")
assertTrue(!viewUtility.contains(".init(named: \"emptyImg\")!"), "ViewUtility should avoid force unwrap asset image")
assertTrue(!timeCheckable.contains("date(bySettingHour: 0, minute: 0, second: 0, of: date)!"), "TimeCheckable should avoid force unwrap date rounding")
assertTrue(!calendarView.contains("bySettingHour: 0, minute: 0, second: 0, of: Date())!"), "Calendar view should avoid force unwrap today")

print("PASS: swift stability unit checks")
