//
//  WatchActionBannerView.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

enum WatchActionBannerStyle: Equatable {
    case card
    case inline
}

struct WatchActionBannerView: View {
    let banner: WatchActionFeedbackBanner
    var style: WatchActionBannerStyle = .card

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: banner.tone.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(banner.tone.tintColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(banner.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(backgroundShape)
        .overlay(alignment: .leading) {
            if style == .inline {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(banner.tone.tintColor)
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
        }
        .accessibilityIdentifier("watch.main.feedbackBanner")
    }

    /// 현재 배너 스타일에 맞는 배경 surface를 계산합니다.
    /// - Returns: 카드형 또는 inline형 watch 배너 배경 뷰입니다.
    @ViewBuilder
    private var backgroundShape: some View {
        switch style {
        case .card:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(banner.tone.backgroundColor)
        case .inline:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(banner.tone.tintColor.opacity(0.22), lineWidth: 1)
                )
        }
    }
}
