//
//  ContentView.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentsViewModel()

    private var durationText: String {
        let total = Int(viewModel.walkingTime)
        let min = total / 60
        let sec = total % 60
        return String(format: "%02d:%02d", min, sec)
    }

    private var lastSyncText: String {
        guard viewModel.lastSyncAt > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: viewModel.lastSyncAt)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(viewModel.isWalking ? "산책 중" : "대기 중")
            Text("시간 \(durationText)")
                .font(.footnote)
            Text(String(format: "넓이 %.1f㎡", viewModel.walkingArea))
                .font(.footnote)
            Text(viewModel.isReachable ? "연결됨" : "오프라인 큐")
                .font(.caption2)
                .foregroundStyle(viewModel.isReachable ? .green : .orange)
            Text("큐 \(viewModel.pendingActionCount)건")
                .font(.caption2)
                .foregroundStyle(viewModel.pendingActionCount > 0 ? .orange : .secondary)
            Text("ACK \(viewModel.lastAckActionId.isEmpty ? "-" : String(viewModel.lastAckActionId.prefix(8)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("동기화 \(lastSyncText)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if viewModel.isWalking {
                Button("영역 표시하기") {
                    viewModel.sendAction(.addPoint)
                }
                Button("산책 종료") {
                    viewModel.sendAction(.endWalk)
                }
            } else {
                Button("산책 시작") {
                    viewModel.sendAction(.startWalk)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
