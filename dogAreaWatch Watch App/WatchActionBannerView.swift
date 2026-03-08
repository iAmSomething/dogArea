//
//  WatchActionBannerView.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct WatchActionBannerView: View {
    let banner: WatchActionFeedbackBanner

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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(banner.tone.backgroundColor)
        )
    }
}
