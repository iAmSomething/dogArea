//
//  ContentView.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @StateObject private var viewModel = ContentsViewModel()
    var body: some View {
        VStack {
            Text(viewModel.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(viewModel.isWalking ? "산책 중" : "산책 대기")
                .font(.headline)
            Text(formatTime(viewModel.walkTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(formatArea(viewModel.walkArea))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Button("시작") {
                    viewModel.sendAction("startWalk")
                }
                .buttonStyle(.borderedProminent)
                Button("종료") {
                    viewModel.sendAction("endWalk")
                }
                .buttonStyle(.bordered)
            }
            Button(action: {
                viewModel.sendAction("addPoint")
            },
                   label: {
                Text("영역 추가하기")
            })
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isWalking)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    private func formatArea(_ area: Double) -> String {
        if area > 100000.0 {
            return String(format: "%.2f k㎡", area / 1000000)
        }
        if area > 10000.0 {
            return String(format: "%.2f 만㎡", area / 10000)
        }
        return String(format: "%.2f ㎡", area)
    }
}

#Preview {
    ContentView()
}
