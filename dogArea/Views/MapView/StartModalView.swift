//
//  StartModalView.swift
//  dogArea
//
//  Created by 김태훈 on 11/9/23.
//

import SwiftUI
struct StartModalView: View {
    @Environment(\.dismiss) var dismiss
    let petName: String
    let onCompleted: () -> Void
    var onCanceled: () -> Void = {}
    @State private var time: TimeInterval = 3
    @State private var countdownTimer: Timer? = nil
    @State private var hasCompleted = false
    var body: some View {
        VStack {
            Text("\(Int(max(0, time)))")
                .font(.appFont(for: .Black, size: 72))
            Text("\(petName)와 함께 출발 준비중")
                .font(.appFont(for: .Regular, size: 16))
                .foregroundStyle(Color.appTextDarkGray)
            Button("취소") {
                cancelCountdown()
            }
            .font(.appFont(for: .SemiBold, size: 18))
            .padding(.top, 20)
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
        hasCompleted = false
        time = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            self.time = max(0, self.time - timer.timeInterval)
            if self.time <= 0 {
                completeCountdown()
            }
        }
    }

    private func completeCountdown() {
        guard hasCompleted == false else { return }
        hasCompleted = true
        invalidateCountdown()
        onCompleted()
        dismiss()
    }

    private func cancelCountdown() {
        guard hasCompleted == false else { return }
        invalidateCountdown()
        onCanceled()
        dismiss()
    }

    private func invalidateCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

#Preview {
    StartModalView(petName: "강아지", onCompleted: {})
}
