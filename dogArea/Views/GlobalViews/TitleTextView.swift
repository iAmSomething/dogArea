//
//  TitleTextView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import SwiftUI

struct TitleTextView: View {
    var title: String
    var type: titleType = .LargeTitle
    var subTitle: String?
    var accessibilityIdentifierPrefix: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(Color.appYellow)
                .frame(width: type == .LargeTitle ? 6 : 4, height: type == .LargeTitle ? 42 : 28)
                .padding(.top, type == .LargeTitle ? 4 : 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(Color.appInk)
                    .lineLimit(type == .LargeTitle ? 2 : 2)
                    .minimumScaleFactor(type == .LargeTitle ? 0.82 : 0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(accessibilityIdentifierPrefix.map { "\($0).title" } ?? "")
                if let subTitle, subTitle.isEmpty == false {
                    Text(subTitle)
                        .font(subTitleFont)
                        .foregroundStyle(Color.appTextDarkGray)
                        .lineLimit(type == .LargeTitle ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(accessibilityIdentifierPrefix.map { "\($0).subtitle" } ?? "")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var titleFont: Font {
        switch type {
        case .LargeTitle:
            return .appScaledFont(for: .Black, size: 47, relativeTo: .largeTitle)
        case .MediumTitle:
            return .appScaledFont(for: .ExtraBold, size: 30, relativeTo: .title2)
        case .SmallTitle:
            return .appScaledFont(for: .SemiBold, size: 22, relativeTo: .headline)
        }
    }

    private var subTitleFont: Font {
        switch type {
        case .LargeTitle:
            return .appScaledFont(for: .Regular, size: 14, relativeTo: .body)
        case .MediumTitle:
            return .appScaledFont(for: .Regular, size: 12, relativeTo: .body)
        case .SmallTitle:
            return .appScaledFont(for: .Light, size: 11, relativeTo: .caption)
        }
    }

    enum titleType {
        case LargeTitle
        case MediumTitle
        case SmallTitle
    }
}

#Preview {
    TitleTextView(title: "제목")
}
