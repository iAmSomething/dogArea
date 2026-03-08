//
//  WatchOfflineQueueStatusCardView.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct WatchOfflineQueueStatusCardView: View {
    let queueStatus: WatchOfflineQueueStatusState
    let onOpenDetail: () -> Void
    let onManualSync: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(queueStatus.summaryTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(queueStatus.summaryTone.tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(queueStatus.summaryTone.backgroundColor)
                    )

                Spacer(minLength: 0)

                Button(action: onOpenDetail) {
                    Text("상세")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            Text(queueStatus.summaryDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if queueStatus.syncRecovery.signals.isEmpty == false {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(queueStatus.syncRecovery.signals.prefix(2)), id: \.self) { signal in
                            infoChip(title: signal.title, tone: signal.tone)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(queueStatus.syncRecovery.signals.prefix(2)), id: \.self) { signal in
                            infoChip(title: signal.title, tone: signal.tone)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    infoChip(
                        title: "큐 \(queueStatus.pendingCount)건",
                        tone: queueStatus.pendingCount > 0 ? .warning : .neutral
                    )
                    if let lastSyncAt = queueStatus.lastSyncAt, lastSyncAt > 0 {
                        infoChip(
                            title: "동기화 \(formattedTimestamp(lastSyncAt))",
                            tone: .neutral
                        )
                    }
                    infoChip(
                        title: "ACK \(queueStatus.lastAckStatus)",
                        tone: .neutral
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    infoChip(
                        title: "큐 \(queueStatus.pendingCount)건",
                        tone: queueStatus.pendingCount > 0 ? .warning : .neutral
                    )
                    if let lastSyncAt = queueStatus.lastSyncAt, lastSyncAt > 0 {
                        infoChip(
                            title: "동기화 \(formattedTimestamp(lastSyncAt))",
                            tone: .neutral
                        )
                    }
                    infoChip(
                        title: "ACK \(queueStatus.lastAckStatus)",
                        tone: .neutral
                    )
                }
            }

            if let warningText = queueStatus.warningText {
                Text(warningText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button(action: onOpenDetail) {
                        Label("큐 상태 보기", systemImage: "tray.full")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)

                    if queueStatus.shouldOfferManualSync {
                        Button(action: onManualSync) {
                            Label(queueStatus.manualSyncButtonTitle, systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(queueStatus.manualSyncButtonTone.tintColor)
                        .disabled(queueStatus.isManualSyncEnabled == false)
                    }
                }

                VStack(spacing: 8) {
                    Button(action: onOpenDetail) {
                        Label("큐 상태 보기", systemImage: "tray.full")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)

                    if queueStatus.shouldOfferManualSync {
                        Button(action: onManualSync) {
                            Label(queueStatus.manualSyncButtonTitle, systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(queueStatus.manualSyncButtonTone.tintColor)
                        .disabled(queueStatus.isManualSyncEnabled == false)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(queueStatus.summaryTone.backgroundColor)
            )
    }

    /// watch 카드용 짧은 시각 문자열을 포맷합니다.
    /// - Parameter timestamp: 초 단위 Unix timestamp입니다.
    /// - Returns: 값이 없으면 `없음`, 있으면 `HH:mm:ss` 형식 문자열입니다.
    private func formattedTimestamp(_ timestamp: TimeInterval?) -> String {
        guard let timestamp, timestamp > 0 else { return "없음" }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 큐 상태 카드 안에서 짧은 상태 배지를 렌더링합니다.
    /// - Parameters:
    ///   - title: 배지에 표시할 요약 문자열입니다.
    ///   - tone: 배지 강조 톤입니다.
    /// - Returns: 짧은 상태 문자열을 담은 배지 뷰입니다.
    private func infoChip(title: String, tone: WatchActionFeedbackTone) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone.tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.backgroundColor)
            )
    }
}
