//
//  WatchOfflineQueueStatusSheetView.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct WatchOfflineQueueStatusSheetView: View {
    let queueStatus: WatchOfflineQueueStatusState
    let onManualSync: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                statusSection
                queuedActionSection
                guidanceSection
            }
            .padding()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("오프라인 큐 상태")
                .font(.headline.weight(.semibold))
            Text(queueStatus.summaryDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: "대기 건수", value: "\(queueStatus.pendingCount)건")
            detailRow(label: "마지막 큐 적재", value: formattedTimestamp(queueStatus.lastQueuedAt))
            detailRow(label: "가장 오래된 요청", value: formattedTimestamp(queueStatus.oldestQueuedAt))
            detailRow(label: "마지막 ACK", value: queueStatus.lastAckStatus)
            detailRow(label: "마지막 ACK 시각", value: formattedTimestamp(queueStatus.lastAckAt))

            if queueStatus.lastAckActionId.isEmpty == false {
                detailRow(label: "마지막 ACK ID", value: queueStatus.lastAckActionId)
            }

            if let warningText = queueStatus.warningText {
                Text(warningText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var queuedActionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("큐에 쌓인 요청")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if queueStatus.queuedActionTitles.isEmpty {
                Text("현재 대기 중인 요청이 없습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(queueStatus.queuedActionTitles, id: \.self) { title in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(.orange)
                            .padding(.top, 5)
                        Text(title)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("중복 전송 안내")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(queueStatus.duplicateInfoText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            Text("다음 행동")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(queueStatus.nextActionText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            if queueStatus.shouldOfferManualSync {
                Button(action: onManualSync) {
                    Label(queueStatus.manualSyncButtonTitle, systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(queueStatus.isManualSyncHighlighted ? .orange : .blue)
                .disabled(queueStatus.isManualSyncEnabled == false)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    /// 큐 상태 시트의 라벨/값 한 줄을 렌더링합니다.
    /// - Parameters:
    ///   - label: 상태 항목 이름입니다.
    ///   - value: 항목 값 문자열입니다.
    /// - Returns: 라벨과 값을 좌우로 배치한 상태 행 뷰입니다.
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }

    /// watch 큐/ACK 타임스탬프를 사용자용 문자열로 포맷합니다.
    /// - Parameter timestamp: 초 단위 Unix timestamp입니다.
    /// - Returns: 값이 없으면 `없음`, 있으면 `HH:mm:ss` 형식 문자열을 반환합니다.
    private func formattedTimestamp(_ timestamp: TimeInterval?) -> String {
        guard let timestamp, timestamp > 0 else { return "없음" }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
