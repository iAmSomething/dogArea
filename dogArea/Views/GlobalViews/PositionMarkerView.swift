//
//  PositionMarkerView.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import SwiftUI

struct PositionMarkerView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.appYellowPale)
            Text("💦").font(.appFont(for: .Bold, size: 10))
                .padding(5)
        }
    }
}
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
