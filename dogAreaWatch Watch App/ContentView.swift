//
//  ContentView.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentsViewModel()

    private var lastSyncText: String {
        guard viewModel.lastSyncAt > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: viewModel.lastSyncAt)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isWalking ? "산책 중" : "대기 중")
                        .font(.headline.weight(.semibold))
                    Text(viewModel.isReachable ? "바로 전송 가능" : "오프라인 큐 모드")
                        .font(.caption2)
                        .foregroundStyle(viewModel.isReachable ? .green : .orange)
                }

                if let feedbackBanner = viewModel.feedbackBanner {
                    WatchActionBannerView(banner: feedbackBanner)
                }

                metricsSection

                VStack(spacing: 8) {
                    if viewModel.isWalking {
                        WatchActionButtonView(
                            presentation: viewModel.controlPresentation(for: .addPoint),
                            action: { viewModel.handleActionTap(.addPoint) }
                        )
                        WatchActionButtonView(
                            presentation: viewModel.controlPresentation(for: .endWalk),
                            action: { viewModel.handleActionTap(.endWalk) }
                        )
                    } else {
                        WatchActionButtonView(
                            presentation: viewModel.controlPresentation(for: .startWalk),
                            action: { viewModel.handleActionTap(.startWalk) }
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("큐 \(viewModel.pendingActionCount)건")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(viewModel.pendingActionCount > 0 ? .orange : .secondary)
                    Text("ACK \(viewModel.lastAckStatus)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("동기화 \(lastSyncText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    private var metricsSection: some View {
        HStack(spacing: 8) {
            metricTile(
                title: "시간",
                value: formatTime(viewModel.walkingTime)
            )
            metricTile(
                title: "넓이",
                value: formatArea(viewModel.walkingArea)
            )
        }
    }

    /// 상단 요약 메트릭 한 칸을 렌더링합니다.
    /// - Parameters:
    ///   - title: 메트릭의 짧은 제목입니다.
    ///   - value: watch 폭에 맞춰 이미 포맷된 값 문자열입니다.
    /// - Returns: 제목과 값을 담은 요약 타일 뷰입니다.
    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    /// 누적 산책 시간을 watch 화면용 문자열로 포맷합니다.
    /// - Parameter time: 초 단위 누적 산책 시간입니다.
    /// - Returns: `mm:ss` 또는 `hh:mm:ss` 형태의 표시 문자열입니다.
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// 누적 산책 영역을 watch 화면용 문자열로 포맷합니다.
    /// - Parameter area: 제곱미터 단위 누적 영역 값입니다.
    /// - Returns: watch 폭에 맞춘 간단한 면적 문자열입니다.
    private func formatArea(_ area: Double) -> String {
        if area > 100000.0 {
            return String(format: "%.2fkm²", area / 1000000)
        }
        if area > 10000.0 {
            return String(format: "%.2f만㎡", area / 10000)
        }
        return String(format: "%.1f㎡", area)
    }
}

#Preview {
    ContentView()
}
