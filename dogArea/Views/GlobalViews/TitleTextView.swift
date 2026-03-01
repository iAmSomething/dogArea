//
//  TitleTextView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import SwiftUI

struct TitleTextView: View {
    @State var title: String
    @State var type: titleType = .LargeTitle
    @State var subTitle: String?
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Capsule()
                .fill(Color.appYellow)
                .frame(width: type == .LargeTitle ? 6 : 4, height: type == .LargeTitle ? 42 : 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                if let subTitle, subTitle.isEmpty == false {
                    Text(subTitle)
                        .font(subTitleFont)
                        .foregroundStyle(Color.appTextDarkGray)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var titleFont: Font {
        switch type {
        case .LargeTitle:
            return .appFont(for: .Black, size: 47) ?? .system(size: 42, weight: .black)
        case .MediumTitle:
            return .appFont(for: .ExtraBold, size: 30) ?? .system(size: 28, weight: .bold)
        case .SmallTitle:
            return .appFont(for: .SemiBold, size: 22) ?? .system(size: 21, weight: .semibold)
        }
    }

    private var subTitleFont: Font {
        switch type {
        case .LargeTitle:
            return .appFont(for: .Regular, size: 14) ?? .system(size: 14, weight: .regular)
        case .MediumTitle:
            return .appFont(for: .Regular, size: 12) ?? .system(size: 12, weight: .regular)
        case .SmallTitle:
            return .appFont(for: .Light, size: 11) ?? .system(size: 11, weight: .light)
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
