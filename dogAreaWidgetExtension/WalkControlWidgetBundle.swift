import WidgetKit
import SwiftUI

@main
struct WalkControlWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        WalkControlWidget()
        TerritoryStatusWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            WalkLiveActivityWidget()
        }
    }
}
