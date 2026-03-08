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
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateText)
                            .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(areaHeadline)
                        .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(sessionSummary)
                        .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
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
                        title: "산책 시간",
                        value: walkData.walkDuration.simpleWalkingTimeInterval,
                        detail: "짧은 산책인지 바로 판단"
                    )
                    WalkListMetricTileView(
                        title: "영역 넓이",
                        value: walkData.walkArea.calculatedAreaString,
                        detail: "얼마나 넓게 확보했는지"
                    )
                    WalkListMetricTileView(
                        title: "포인트 수",
                        value: "\(walkData.locations.count)개",
                        detail: "경로/마커 밀도"
                    )
                    WalkListMetricTileView(
                        title: "반려견",
                        value: petBadgeText,
                        detail: "어느 반려견 기록인지"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ThumbnailImageView(image: walkData.image, size: 92, cornerRadius: 18)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
                .padding(16)
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
        "산책 \(walkData.walkDuration.simpleWalkingTimeInterval) · 포인트 \(walkData.locations.count)개"
    }
}
