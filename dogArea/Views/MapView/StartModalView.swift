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
    @State private var countdownTimer: Timer? = nil
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
            startCountdown()
        }
        .onDisappear {
            invalidateCountdown()
        }
    }

    private func startCountdown() {
        invalidateCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            self.time = max(0, self.time - timer.timeInterval)
            if self.time <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                dismiss()
            }
        }
    }

    private func invalidateCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

#Preview {
    StartModalView()
}
