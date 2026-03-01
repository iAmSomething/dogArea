import SwiftUI

struct PositionMarkerViewWithSelection: View {
    @State var selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(selected ? Color.appPeach : Color.appYellowPale)
            Text("💦").font(.appFont(for: .Bold, size: 10))
                .padding(5)
        }
    }
}
