//
//  StartModalView.swift
//  dogArea
//
//  Created by 김태훈 on 11/9/23.
//

import SwiftUI
struct StartModalView: View {
    @Environment(\.dismiss) var dismiss
    @State var time: TimeInterval = 3
    var body: some View {
        VStack {
            if Int(time) < 1 {
                Text("산책을 시작합니다.")
                    .font(.extraBold28)
            }
            else {
                Text("\(Int(time))")
                    .font(.appFont(for: .Black, size: 72))
            }
        }.onAppear() {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { t in
                self.time -= t.timeInterval
            })
        }
    }
}

#Preview {
    StartModalView()
}
