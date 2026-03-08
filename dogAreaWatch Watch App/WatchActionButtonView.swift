//
//  WatchActionButtonView.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct WatchActionButtonView: View {
    let presentation: WatchActionControlPresentation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if presentation.showsProgress {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.primary)
                } else {
                    Image(systemName: presentation.tone.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(presentation.tone.tintColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(presentation.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(presentation.tone.backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(presentation.isDisabled)
        .opacity(presentation.isDisabled ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
