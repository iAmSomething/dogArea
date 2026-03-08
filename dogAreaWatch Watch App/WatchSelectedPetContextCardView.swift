//
//  WatchSelectedPetContextCardView.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct WatchSelectedPetContextCardView: View {
    let petContext: WatchSelectedPetContextState
    let isReachable: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(petContext.badgeTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(petContext.tone.tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(petContext.tone.backgroundColor)
                    )

                Spacer(minLength: 0)

                Text(isReachable ? "iPhone 연결됨" : "오프라인")
                    .font(.caption2)
                    .foregroundStyle(isReachable ? .green : .orange)
            }

            Text(petContext.petName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(petContext.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text(petContext.note)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if petContext.showsRefreshAction(isReachable: isReachable) {
                Button(action: onRefresh) {
                    Label("반려견 다시 확인", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(petContext.tone.tintColor)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(petContext.tone.backgroundColor)
        )
    }
}
