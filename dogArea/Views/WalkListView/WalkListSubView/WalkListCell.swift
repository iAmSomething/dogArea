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
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dateTimeSummary)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)

                Text(areaHeadline)
                    .font(.appScaledFont(for: .SemiBold, size: 17, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)

                Label {
                    Text(petBadgeText)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x78350F, dark: 0xFDE68A))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFCD34D))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1F2937, alpha: 0.95))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.appDynamicHex(light: 0xFCD68A, dark: 0x334155, alpha: 0.6), lineWidth: 1)
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6, alignment: .top),
                        GridItem(.flexible(), spacing: 6, alignment: .top),
                    ],
                    alignment: .leading,
                    spacing: 6
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

            ThumbnailImageView(image: walkData.image, size: 76, cornerRadius: 14)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
                .padding(12)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var dateTimeSummary: String {
        "\(walkData.createdAt.createdAtTimeCustom(format: "yyyy.MM.dd (E)")) · \(walkData.createdAt.createdAtTimeCustom(format: "HH:mm 시작"))"
    }

    private var petBadgeText: String {
        guard let petName, petName.isEmpty == false else {
            if ProcessInfo.processInfo.arguments.contains("-UITest.WalkListLongMetricPreview") {
                return "이름이 긴 반려견 산책 샘플"
            }
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
