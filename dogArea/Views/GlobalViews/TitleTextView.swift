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
        HStack(alignment: .bottom) {
            switch type {
            case .LargeTitle :
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.appFont(for: .SemiBold, size: 40))
                    if subTitle != nil {
                        Text(subTitle!)
                            .font(.appFont(for: .Light, size: 15))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                }.padding()
            case .MediumTitle :
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.appFont(for: .SemiBold, size: 25))
                    if subTitle != nil {
                        Text(subTitle!)
                            .font(.appFont(for: .Light, size: 11))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                }.padding()
            case .SmallTitle :
                    Text(title)
                        .font(.appFont(for: .SemiBold, size: 20))
            }
            Spacer()

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
