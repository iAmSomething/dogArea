import WidgetKit
import SwiftUI

@main
struct WalkControlWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        WalkControlWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            WalkLiveActivityWidget()
        }
    }
}
