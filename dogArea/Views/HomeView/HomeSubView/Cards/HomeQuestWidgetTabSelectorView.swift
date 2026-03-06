import SwiftUI

struct HomeQuestWidgetTabSelectorView: View {
    let selectedTab: HomeQuestWidgetTab
    let onSelectTab: (HomeQuestWidgetTab) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(HomeQuestWidgetTab.allCases) { tab in
                Button(tab.title) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onSelectTab(tab)
                    }
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedTab == tab ? Color.appYellow : Color.appTextLightGray.opacity(0.35))
                .cornerRadius(8)
            }
            Spacer()
        }
    }
}
