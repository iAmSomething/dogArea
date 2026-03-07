import Foundation

@discardableResult
func require(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to read \(relativePath)\n", stderr)
        exit(1)
    }
    return content
}

let snapshotStore = read("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let widgetView = read("dogAreaWidgetExtension/Widgets/HotspotStatusWidget.swift")
let bridge = read("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")
let rootView = read("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let rivalView = read("dogArea/Views/ProfileSettingView/RivalTabView.swift")
let rivalViewModel = read("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")
let rivalFlow = read("dogArea/Views/ProfileSettingView/RivalTabViewModelSupport/RivalTabViewModel+SharingAndLeaderboard.swift")
let doc = read("docs/hotspot-widget-radius-preset-v1.md")

require(snapshotStore.contains("enum HotspotWidgetRadiusPreset"), "반경 preset enum이 없습니다.")
require(snapshotStore.contains("case nearby"), "0.5km preset 정의가 없습니다.")
require(snapshotStore.contains("case balanced"), "1km preset 정의가 없습니다.")
require(snapshotStore.contains("case broad"), "3km preset 정의가 없습니다.")
require(snapshotStore.contains("func load(radiusPreset: HotspotWidgetRadiusPreset)"), "preset별 snapshot load 경로가 없습니다.")
require(widgetView.contains("struct HotspotWidgetConfigurationIntent: WidgetConfigurationIntent"), "핫스팟 위젯 configuration intent가 없습니다.")
require(widgetView.contains("AppIntentConfiguration("), "핫스팟 위젯이 AppIntentConfiguration을 사용하지 않습니다.")
require(widgetView.contains(".widgetURL(routeURL)"), "핫스팟 위젯 딥링크 연결이 없습니다.")
require(bridge.contains("struct HotspotWidgetDeepLinkRoute"), "핫스팟 위젯 딥링크 라우트가 없습니다.")
require(rootView.contains("-UITest.HotspotWidgetRoutePreset"), "핫스팟 위젯 UI 테스트 라우트 인자가 없습니다.")
require(rootView.contains("dispatchHotspotWidgetRoute"), "RootView가 핫스팟 위젯 라우트를 처리하지 않습니다.")
require(rivalView.contains("rival.hotspot.radius.current"), "Rival 탭 반경 표시 식별자가 없습니다.")
require(rivalView.contains("rival.hotspot.radius.picker"), "Rival 탭 반경 picker 식별자가 없습니다.")
require(rivalViewModel.contains("hotspotRadiusPreset"), "Rival 뷰모델에 현재 반경 상태가 없습니다.")
require(rivalFlow.contains("applyExternalRoute(_ route: RivalExternalRoute)"), "외부 반경 문맥 적용 로직이 없습니다.")
require(doc.contains("## Preset"), "preset 문서 섹션이 없습니다.")
require(doc.contains("## 앱 상세 연계"), "앱 상세 연계 문서 섹션이 없습니다.")

print("PASS: hotspot widget radius preset wiring is in place")
