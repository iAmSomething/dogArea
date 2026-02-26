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
    @State private var timer: Timer?
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
        }
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                time -= t.timeInterval
                if time <= 0 {
                    t.invalidate()
                    timer = nil
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

#Preview {
    StartModalView()
}
