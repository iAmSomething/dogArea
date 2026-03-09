//
//  WalkListCell.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import SwiftUI

struct WalkListCell: View {
    let walkData: WalkDataModel
    let petName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateText)
                            .font(.appScaledFont(for: .SemiBold, size: 17, relativeTo: .headline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(timeText)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    }

                    Spacer(minLength: 0)

                    Text(petBadgeText)
                        .appPill(isActive: petName?.isEmpty == false)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(areaHeadline)
                        .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(sessionSummary)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8, alignment: .top),
                        GridItem(.flexible(), spacing: 8, alignment: .top),
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    WalkListMetricTileView(
                        title: "시간",
                        value: walkDurationText,
                        detail: nil,
                        accessibilityIdentifier: metricAccessibilityIdentifier("duration")
                    )
                    WalkListMetricTileView(
                        title: "넓이",
                        value: walkAreaText,
                        detail: nil,
                        accessibilityIdentifier: metricAccessibilityIdentifier("area")
                    )
                    WalkListMetricTileView(
                        title: "포인트",
                        value: walkPointCountText,
                        detail: nil,
                        accessibilityIdentifier: metricAccessibilityIdentifier("points")
                    )
                    WalkListMetricTileView(
                        title: "반려견",
                        value: petBadgeText,
                        detail: nil,
                        accessibilityIdentifier: metricAccessibilityIdentifier("pet")
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ThumbnailImageView(image: walkData.image, size: 84, cornerRadius: 16)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
                .padding(14)
        }
    }

    private var dateText: String {
        walkData.createdAt.createdAtTimeCustom(format: "yyyy.MM.dd (E)")
    }

    private var timeText: String {
        walkData.createdAt.createdAtTimeCustom(format: "HH:mm 시작")
    }

    private var petBadgeText: String {
        guard let petName, petName.isEmpty == false else {
            return "반려견 미지정"
        }
        return petName
    }

    private var areaHeadline: String {
        if walkData.walkArea > 0 {
            return "\(walkData.walkArea.calculatedAreaString) 확보"
        }
        return "산책 기록"
    }

    private var sessionSummary: String {
        "\(timeText) · \(walkPointCountText)"
    }

    private var walkDurationText: String {
        walkData.walkDuration.simpleWalkingTimeInterval
    }

    private var walkAreaText: String {
        walkData.walkArea.calculatedAreaString
    }

    private var walkPointCountText: String {
        "\(walkData.locations.count)개"
    }

    private func metricAccessibilityIdentifier(_ suffix: String) -> String {
        "walklist.cell.\(walkData.id.uuidString.lowercased()).metric.\(suffix)"
    }
}
